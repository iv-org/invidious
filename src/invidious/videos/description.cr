require "json"
require "uri"

# YouTube provides startIndex/length in UTF-16 code units.
# Supplementary codepoints (emojis, rare CJK) are 2 UTF-16 units (surrogate pair)
# but 1 Crystal codepoint. Counting in codepoints causes misaligned links.
private def utf16_len(cp : Int) : Int
  cp > 0xFFFF ? 2 : 1
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
    elsif cp == 0x3E # Greater-than (>)
      str << "&gt;"
    else
      str << cp.chr
    end

    copied += utf16_len(cp)
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
      copy_string(str, content.each_codepoint, Int32::MAX)
    end
  end

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
      if on_tap = command.dig?("onTap", "innertubeCommand")
        link = parse_link_endpoint(on_tap, cmd_content, video_id)
      end
      str << link
      index += cmd_length
    end

    # Copy the rest of the string (past the last command).
    copy_string(str, iter, Int32::MAX)
  end
end
