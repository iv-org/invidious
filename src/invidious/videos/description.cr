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

def parse_description(desc, video_id : String) : String?
  return "" if desc.nil?

  content = desc["content"].as_s
  return "" if content.empty?

  # attachmentRuns contains custom emoji URLs
  attachments = desc["attachmentRuns"]?.try &.as_a || [] of JSON::Any

  commands = desc["commandRuns"]?.try &.as_a || [] of JSON::Any

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
  iter = content.each_codepoint

  index = 0

  return String.build do |str|
    # Combine commandRuns and attachmentRuns into one array
    events = commands + attachments

    events.each do |event|
      cmd_start = event["startIndex"].as_i
      cmd_length = event["length"].as_i

      # Copy the text chunk between this command and the previous if needed.
      length = cmd_start - index
      index += copy_string(str, iter, length)

      # We need to copy the command's text using the iterator
      # and the special function defined above.
      cmd_content = String.build(cmd_length) do |str2|
        copy_string(str2, iter, cmd_length)
      end

      # Check if event is an attachment AND a custom emoji using regex. Format is :<name>:
      # Members-only custom emojis have prefix :_ Built in YouTube emojis do not
      if (image = event.dig?("element", "type", "imageType", "image")) && cmd_content.matches?(/^:[^:\s]+:$/)
        # Source contains the emoji URL, height, and width
        source = image["sources"][0]

        # Extract the emoji name
        label = event.dig?("element", "properties", "accessibilityProperties", "label").try &.as_s || ""

        # Apply channel-emoji CSS to add margin around emoji
        str << %(<img class="channel-emoji" alt=")
        str << HTML.escape(label)
        str << %(" src="/ggpht)
        str << URI.parse(url = source["url"].as_s).request_target
        str << %(" title=")
        str << HTML.escape(label)
        str << %(" width=")
        str << source["width"]?.to_s
        str << %(" height=")
        str << source["height"]?.to_s
        str << %(" />)

        index += cmd_length
      else
        link = cmd_content
        if on_tap = event.dig?("onTap", "innertubeCommand")
          link = parse_link_endpoint(on_tap, cmd_content, video_id)
        end
        str << link
        index += cmd_length
      end
    end
    # Copy the end of the string (past the last command).
    content_size = content.ascii_only? ? content.size : utf16_length(content)
    remaining_length = content_size - index
    copy_string(str, iter, remaining_length) if remaining_length > 0
  end
end
