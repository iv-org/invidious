require "json"
require "uri"

def parse_command(command : JSON::Any?, string : String) : String?
  on_tap = command.dig?("onTap", "innertubeCommand")

  # 3rd party URL, extract original URL from YouTube tracking URL
  if url_endpoint = on_tap.try &.["urlEndpoint"]?
    youtube_url = URI.parse url_endpoint["url"].as_s

    original_url = youtube_url.query_params["q"]?
    if original_url.nil?
      return ""
    else
      return "<a href=\"#{original_url}\">#{original_url}</a>"
    end
    # 1st party watch URL
  elsif watch_endpoint = on_tap.try &.["watchEndpoint"]?
    video_id = watch_endpoint["videoId"].as_s
    time = watch_endpoint["startTimeSeconds"].as_i

    url = "/watch?v=#{video_id}&t=#{time}s"

    # if string is a timestamp, use the string instead
    # this is a lazy regex for validating timestamps
    if /(?:\d{1,2}:){1,2}\d{2}/ =~ string
      return "<a href=\"#{url}\">#{string}</a>"
    else
      return "<a href=\"#{url}\">#{url}</a>"
    end
    # hashtag/other browse URLs
  elsif browse_endpoint = on_tap.try &.dig?("commandMetadata", "webCommandMetadata")
    url = browse_endpoint["url"].try &.as_s

    # remove unnecessary character in a channel name
    if browse_endpoint["webPageType"]?.try &.as_s == "WEB_PAGE_TYPE_CHANNEL"
      name = string.match(/@[\w\d.-]+/)
      if name.try &.[0]?
        return "<a href=\"#{url}\">#{name.try &.[0]}</a>"
      end
    end

    return "<a href=\"#{url}\">#{string}</a>"
  end

  return "(unknown YouTube desc command)"
end

private def copy_string(str : String::Builder, iter : Iterator, count : Int) : Int
  copied = 0
  while copied < count
    cp = iter.next
    break if cp.is_a?(Iterator::Stop)

    str << cp.chr

    # A codepoint from the SMP counts twice
    copied += 1 if cp > 0xFFFF
    copied += 1
  end

  return copied
end

def parse_description(desc : JSON::Any?) : String?
  return "" if desc.nil?

  content = desc["content"].as_s
  return "" if content.empty?

  commands = desc["commandRuns"]?.try &.as_a
  return content if commands.nil?

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

      str << parse_command(command, cmd_content)
      index += cmd_length
    end

    # Copy the end of the string (past the last command).
    remaining_length = content.size - index
    copy_string(str, iter, remaining_length) if remaining_length > 0
  end
end
