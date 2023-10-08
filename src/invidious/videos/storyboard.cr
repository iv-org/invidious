require "uri"
require "http/params"

module Invidious::Videos
  struct Storyboard
    # Parse the JSON structure from Youtube
    def self.from_yt_json(container : JSON::Any)
      storyboards = container.dig?("playerStoryboardSpecRenderer", "spec")
        .try &.as_s.split("|")

      if !storyboards
        if storyboard = container.dig?("playerLiveStoryboardSpecRenderer", "spec").try &.as_s
          return [{
            url:               storyboard.split("#")[0],
            width:             106,
            height:            60,
            count:             -1,
            interval:          5000,
            storyboard_width:  3,
            storyboard_height: 3,
            storyboard_count:  -1,
          }]
        end
      end

      items = [] of NamedTuple(
        url: String,
        width: Int32,
        height: Int32,
        count: Int32,
        interval: Int32,
        storyboard_width: Int32,
        storyboard_height: Int32,
        storyboard_count: Int32)

      return items if !storyboards

      url = URI.parse(storyboards.shift)
      params = HTTP::Params.parse(url.query || "")

      storyboards.each_with_index do |sb, i|
        width, height, count, storyboard_width, storyboard_height, interval, _, sigh = sb.split("#")
        params["sigh"] = sigh
        url.query = params.to_s

        width = width.to_i
        height = height.to_i
        count = count.to_i
        interval = interval.to_i
        storyboard_width = storyboard_width.to_i
        storyboard_height = storyboard_height.to_i
        storyboard_count = (count / (storyboard_width * storyboard_height)).ceil.to_i

        items << {
          url:               url.to_s.sub("$L", i).sub("$N", "M$M"),
          width:             width,
          height:            height,
          count:             count,
          interval:          interval,
          storyboard_width:  storyboard_width,
          storyboard_height: storyboard_height,
          storyboard_count:  storyboard_count,
        }
      end

      items
    end
  end
end
