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

  commands = desc["commandRuns"]?.try &.as_a
  if commands.nil?
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
    commands.each do |command|
      cmd_start = command["startIndex"].as_i
      cmd_length = command["length"].as_i

      # Copy the text chunk between this command and the previous if needed.
      length = cmd_start - index
      index += copy_string(str, iter, length)

      # We need to copy the command's text using the iterator
      # and the special function defined above.
      cmd_content = String.build(cmd_length) do |str2|
        copy_string(str2, iter, cmd_length)
      end

      link = cmd_content
      
      if command["emoji"]?
        if emoji_image = command.dig?("emoji", "image")
          thumbnails = emoji_image["thumbnails"]?.try &.as_a?
          if thumbnails && (emoji_thumb = thumbnails.first?) && (thumb_url = emoji_thumb["url"]?.try &.as_s?)
            raw_label = emoji_image.dig?("accessibility", "accessibilityData", "label").try &.as_s?
            emoji_alt = raw_label ? HTML.escape(raw_label) : cmd_content

            link = String.build do |s|
              s << %(<img alt=") << emoji_alt << "\" "
              s << %(src="/ggpht) << URI.parse(thumb_url).request_target << "\" "
              s << %(title=") << emoji_alt << "\" "
              if thumb_width = emoji_thumb["width"]?
                s << %(width=") << thumb_width << "\" "
              end
              if thumb_height = emoji_thumb["height"]?
                s << %(height=") << thumb_height << "\" "
              end
              s << %(class="channel-emoji" />)
            end
          end
        else
          link = "" if link.starts_with?(':') && link.ends_with?(':')
        end
      end

      if on_tap = command.dig?("onTap", "innertubeCommand")
        link = parse_link_endpoint(on_tap, link, video_id)
      end
      str << link
      index += cmd_length
    end

    # Copy the end of the string (past the last command).
    content_size = content.ascii_only? ? content.size : utf16_length(content)
    remaining_length = content_size - index
    copy_string(str, iter, remaining_length) if remaining_length > 0
  end
end
