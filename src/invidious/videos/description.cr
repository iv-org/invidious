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

    # if text is a timestamp, use the string instead
    if /(?:\d{2}:){1,2}\d{2}/ =~ string
      return "<a href=\"#{url}\">#{string}</a>"
    else
      return "<a href=\"#{url}\">#{url}</a>"
    end
    # hashtag/other browse URLs
  elsif browse_endpoint = on_tap.try &.dig?("commandMetadata", "webCommandMetadata")
    url = browse_endpoint["url"].try &.as_s

    # remove unnecessary character in a channel name
    if browse_endpoint["webPageType"]?.try &.as_s == "WEB_PAGE_TYPE_CHANNEL"
      name = string.match(/@[\w\d]+/)
      if name.try &.[0]?
        return "<a href=\"#{url}\">#{name.try &.[0]}</a>"
      end
    end

    return "<a href=\"#{url}\">#{string}</a>"
  end

  return "(unknown YouTube desc command)"
end

def parse_description(desc : JSON::Any?) : String?
  if desc.nil?
    return ""
  end

  content = desc["content"].as_s
  if content.empty?
    return ""
  end

  if commands = desc["commandRuns"]?.try &.as_a
    description = String.build do |str|
      index = 0
      commands.each do |command|
        start_index = command["startIndex"].as_i
        length = command["length"].as_i

        if start_index > 0 && start_index - index > 0
          str << content[index..(start_index - 1)]
          index += start_index - index
        end

        str << parse_command(command, content[start_index, length])
        index += length
      end
      if index < content.size
        str << content[index..content.size]
      end
    end
    return description
  end

  return content
end
