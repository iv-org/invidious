require "html"
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

private def render_description_attachment(attachment : JSON::Any, fallback : String) : String?
  source = attachment.dig?("element", "type", "imageType", "image", "sources", 0)
  return if source.nil?

  source_url = source["url"]?.try &.as_s?
  return if source_url.nil?

  uri = URI.parse(source_url)
  return if uri.scheme != "https"

  # Custom emoji URLs use either host; the existing /ggpht proxy serves the
  # same request path through yt3.ggpht.com.
  return unless {"lh3.googleusercontent.com", "yt3.ggpht.com"}.includes?(uri.host)

  label = attachment.dig?("properties", "accessibilityProperties", "label").try &.as_s? || fallback
  width = source["width"]?.try &.as_i? || 16_i64
  height = source["height"]?.try &.as_i? || 16_i64

  String.build do |str|
    str << %(<img alt=") << HTML.escape(label) << %(" )
    str << %(src="/ggpht) << HTML.escape(uri.request_target) << %(" )
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

  # Not everything is stored in UTF-8 on youtube's side. The SMP codepoints
  # (0x10000 and above) are encoded as UTF-16 surrogate pairs, which are
  # automatically decoded by the JSON parser. It means that we need to count
  # copied byte in a special manner, preventing the use of regular string copy.
  runs = [] of NamedTuple(start: Int32, length: Int32, attachment: Bool, data: JSON::Any)
  commands.try &.each do |command|
    runs << {start: command["startIndex"].as_i, length: command["length"].as_i, attachment: false, data: command}
  end
  attachments.try &.each do |attachment|
    runs << {start: attachment["startIndex"].as_i, length: attachment["length"].as_i, attachment: true, data: attachment}
  end
  runs.sort_by! { |run| {run[:start], run[:attachment] ? 0 : 1} }

  iter = content.each_codepoint

  index = 0

  return String.build do |str|
    runs.each do |run|
      run_start = run[:start]
      run_length = run[:length]

      # If command and attachment runs overlap, ignore a lower-priority run
      # once that section has already been consumed.
      next if run_start < index

      # Copy the text chunk between this run and the previous if needed.
      length = run_start - index
      index += copy_string(str, iter, length)

      # We need to copy the run's text using the iterator and the special
      # function defined above.
      run_content = String.build(run_length) do |str2|
        copy_string(str2, iter, run_length)
      end

      if run[:attachment] && run_length > 0
        str << (render_description_attachment(run[:data], run_content) || run_content)
      else
        link = run_content
        if on_tap = run[:data].dig?("onTap", "innertubeCommand")
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
