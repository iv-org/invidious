require "json"
require "uri"

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

    copied += 1
  end

  return copied
end

# YouTube provides startIndex and length values in UTF-16 code units
# (where supplementary characters like emoji count as 2), but Crystal's
# String#each_codepoint iterates Unicode codepoints (where each emoji
# counts as 1). This mismatch causes links to be misaligned when the
# description contains emoji or other supplementary characters before a link.
#
# This iterator yields one unit per UTF-16 code unit, so that the existing
# copy_string logic works correctly with YouTube's indices. Each BMP character
# yields itself once; each supplementary character (codepoint >= 0x10000)
# yields its high surrogate then its low surrogate.
private class UTF16CodeUnitIterator
  include Iterator(UInt32)

  @codepoints : Array(UInt32)
  @index : Int32 = 0
  @pending : UInt32? = nil

  def initialize(@codepoints)
  end

  def next
    if pending = @pending
      @pending = nil
      return pending
    end

    if @index >= @codepoints.size
      return Iterator::Stop::INSTANCE
    end

    cp = @codepoints[@index]
    @index += 1

    if cp >= 0x10000
      # Encode as UTF-16 surrogate pair
      cp -= 0x10000
      high = 0xD800_u32 + (cp >> 10)
      low = 0xDC00_u32 + (cp & 0x3FF)
      @pending = low
      return high
    end

    return cp
  end
end

private def utf16_codeunit_iter(content : String)
  UTF16CodeUnitIterator.new(content.codepoints)
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
      copy_string(str, content.each_codepoint, content.size)
    end
  end

  # YouTube's startIndex/length are measured in UTF-16 code units.
  # We must iterate using UTF-16 code units so that indices align correctly,
  # even when the description contains emoji or other supplementary characters.
  iter = utf16_codeunit_iter(content)

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

    # Copy the end of the string (past the last command).
    remaining_length = content.size - index
    copy_string(str, iter, remaining_length) if remaining_length > 0
  end
end
