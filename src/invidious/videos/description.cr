require "json"
require "uri"

# size < bytesize, so we need to count the number of characters that are
# two UInt16 wide.
# Taken from: https://github.com/crystal-lang/crystal/blob/8fa7f90c091aa3757821c04ee243c7ab5f67ac20/src/string/utf16.cr#L18-L20
private def utf16_length(content : String) : Int32
  u16_size = 0
  content.each_char do |char|
    u16_size += char.ord < 0x1_0000 ? 1 : 2
  end
  u16_size
end

private def copy_string(str : String::Builder, iter : Iterator, count : Int) : Int
  copied = 0
  while copied < count
    cp = iter.next
    break if cp.is_a?(Iterator::Stop)

    if cp == 0x26 # Ampersand (&)
      str << "&amp;"
    elsif cp == 0x27 # Single quote (')
      str << "&#39;"
    elsif cp == 0x22 # Double quote (")
      str << "&quot;"
    elsif cp == 0x3C # Less-than (<)
      str << "&lt;"
    elsif cp == 0x3E # Greater than (>)
      str << "&gt;"
    else
      str << cp.chr
    end

    # A codepoint from the SMP counts twice
    copied += 1 if cp > 0xFFFF
    copied += 1
  end

  return copied
end

# Custom channel emoji are sent as an attachment run holding the image, while
# the text content only carries a ":shortcode:" placeholder. If the image is
# not substituted in, that raw placeholder is what gets displayed.
#
# Standard Unicode emoji are sent as attachment runs too, but their text
# content is the emoji character itself, which already renders correctly. Those
# are left as-is, so we don't proxy an image for every single emoji.
private def attachment_run_to_html(run : JSON::Any, text : String) : String
  return text if !(text.starts_with?(':') && text.ends_with?(':') && text.size > 2)

  source = run.dig?("element", "type", "imageType", "image", "sources", 0)
  return text if source.nil?

  url = source["url"]?.try &.as_s
  return text if url.nil?

  label = run.dig?("element", "properties", "accessibilityProperties", "label")
    .try &.as_s || text
  width = source["width"]?.try &.as_i? || 16
  height = source["height"]?.try &.as_i? || 16

  return String.build do |str|
    str << %(<img alt=") << HTML.escape(label) << %(" )
    str << %(src="/ggpht) << URI.parse(url).request_target << %(" )
    str << %(title=") << HTML.escape(label) << %(" )
    str << %(width=") << width << %(" )
    str << %(height=") << height << %(" )
    str << %(class="channel-emoji" />)
  end
end

def parse_description(desc, video_id : String) : String?
  return "" if desc.nil?

  content = desc["content"].as_s
  return "" if content.empty?

  commands = desc["commandRuns"]?.try &.as_a
  attachments = desc["attachmentRuns"]?.try &.as_a

  if commands.nil? && attachments.nil?
    # Slightly faster than HTML.escape, as we're only doing one pass on
    # the string instead of five for the standard library
    return String.build do |str|
      content_size = content.ascii_only? ? content.size : utf16_length(content)
      copy_string(str, content.each_codepoint, content_size)
    end
  end

  # Both kinds of run index into the same string, so they have to be walked
  # together in positional order.
  runs = [] of {Int32, Int32, Bool, JSON::Any}
  commands.try &.each do |command|
    runs << {command["startIndex"].as_i, command["length"].as_i, false, command}
  end
  attachments.try &.each do |attachment|
    runs << {attachment["startIndex"].as_i, attachment["length"].as_i, true, attachment}
  end
  runs.sort_by! { |run| run[0] }

  # Not everything is stored in UTF-8 on youtube's side. The SMP codepoints
  # (0x10000 and above) are encoded as UTF-16 surrogate pairs, which are
  # automatically decoded by the JSON parser. It means that we need to count
  # copied byte in a special manner, preventing the use of regular string copy.
  iter = content.each_codepoint

  index = 0

  return String.build do |str|
    runs.each do |(run_start, run_length, is_attachment, run)|
      # A command and an attachment can cover the same characters. The
      # iterator can only move forward, so skip anything already consumed.
      next if run_start < index

      # Copy the text chunk between this run and the previous if needed.
      length = run_start - index
      index += copy_string(str, iter, length)

      # We need to copy the run's text using the iterator
      # and the special function defined above.
      run_content = String.build(run_length) do |str2|
        copy_string(str2, iter, run_length)
      end

      if is_attachment
        str << attachment_run_to_html(run, run_content)
      else
        link = run_content
        if on_tap = run.dig?("onTap", "innertubeCommand")
          link = parse_link_endpoint(on_tap, run_content, video_id)
        end
        str << link
      end

      index += run_length
    end

    # Copy the end of the string (past the last command).
    content_size = content.ascii_only? ? content.size : utf16_length(content)
    remaining_length = content_size - index
    copy_string(str, iter, remaining_length) if remaining_length > 0
  end
end
