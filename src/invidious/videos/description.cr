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

private def skip_string(iter : Iterator, count : Int) : Nil
  copied = 0
  while copied < count
    cp = iter.next
    break if cp.is_a?(Iterator::Stop)

    # A codepoint from the SMP counts twice
    copied += 1 if cp > 0xFFFF
    copied += 1
  end
end

# Builds an <img> tag for a given attachment run. Only images hosted on
# domains proxied through /ggpht are supported; attachments pointing at
# www.youtube.com (standard unicode emojis rendered as images by YouTube)
# return nil, as the underlying text characters already render fine.
private def attachment_to_img(attachment : JSON::Any) : String?
  source = attachment.dig?("element", "type", "imageType", "image", "sources", 0)
  url = source.try &.dig?("url").try &.as_s
  return unless url

  uri = URI.parse(url)
  host = uri.host.try &.downcase
  return unless host.try(&.ends_with?("ggpht.com")) ||
                host.try(&.ends_with?("googleusercontent.com"))

  alt = attachment.dig?("element", "properties", "accessibilityProperties", "label").try &.as_s || ""
  width = source.try &.dig?("width").try &.as_i || 16
  height = source.try &.dig?("height").try &.as_i || 16

  String.build do |str|
    str << %(<img alt=") << HTML.escape(alt) << "\" "
    str << %(title=") << HTML.escape(alt) << "\" "
    str << %(src="/ggpht) << uri.request_target << "\" "
    str << %(width=") << width << "\" "
    str << %(height=") << height << "\" "
    str << %(class="channel-emoji" />)
  end
end

def parse_description(desc, video_id : String) : String?
  return "" if desc.nil?

  content = desc["content"].as_s
  return "" if content.empty?

  commands = (desc["commandRuns"]?.try &.as_a) || Array(JSON::Any).new
  attachments = (desc["attachmentRuns"]?.try &.as_a) || Array(JSON::Any).new
  # Only image attachments are supported for now
  attachments = attachments.select do |attachment|
    attachment.dig?("element", "type", "imageType", "image", "sources", 0, "url")
  end

  if commands.empty? && attachments.empty?
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
  #
  # Links (commandRuns) and image attachments (attachmentRuns, used for custom
  # channel emojis) share the same startIndex/length coordinate space and are
  # merged into one ordered list of runs below.
  runs = [] of {Int32, Int32, JSON::Any, Bool}
  commands.each do |command|
    runs << {command["startIndex"].as_i, command["length"].as_i, command, false}
  end
  attachments.each do |attachment|
    runs << {attachment["startIndex"].as_i, attachment["length"].as_i, attachment, true}
  end
  runs.sort_by!(&.[0])

  iter = content.each_codepoint

  index = 0

  return String.build do |str|
    runs.each do |(start, length, node, is_attachment)|
      # Defensive check against overlapping runs
      next if start < index

      # Copy the text chunk between this run and the previous one if needed.
      gap = start - index
      index += copy_string(str, iter, gap)

      if img = is_attachment ? attachment_to_img(node) : nil
        # Skip the attached characters: the image replaces them entirely.
        skip_string(iter, length)
        str << img
      else
        # We need to copy the command's text using the iterator
        # and the special function defined above.
        cmd_content = String.build(length) do |str2|
          copy_string(str2, iter, length)
        end

        link = cmd_content
        if !is_attachment && (on_tap = node.dig?("onTap", "innertubeCommand"))
          link = parse_link_endpoint(on_tap, cmd_content, video_id)
        end
        str << link
      end
      index += length
    end

    # Copy the end of the string (past the last run).
    content_size = content.ascii_only? ? content.size : utf16_length(content)
    remaining_length = content_size - index
    copy_string(str, iter, remaining_length) if remaining_length > 0
  end
end
