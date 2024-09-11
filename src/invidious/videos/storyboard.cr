require "uri"
require "http/params"

module Invidious::Videos
  struct Storyboard
    # Template URL
    getter url : URI
    getter proxied_url : URI

    # Thumbnail parameters
    getter width : Int32
    getter height : Int32
    getter count : Int32
    getter interval : Int32

    # Image (storyboard) parameters
    getter rows : Int32
    getter columns : Int32
    getter images_count : Int32

    def initialize(
      *, @url, @width, @height, @count, @interval,
      @rows, @columns, @images_count
    )
      authority = /(i\d?).ytimg.com/.match!(@url.host.not_nil!)[1]?

      @proxied_url = URI.parse(HOST_URL)
      @proxied_url.path = "/sb/#{authority}/#{@url.path.lchop("/sb/")}"
      @proxied_url.query = @url.query
    end

    # Parse the JSON structure from Youtube
    def self.from_yt_json(container : JSON::Any, length_seconds : Int32) : Array(Storyboard)
      # Livestream storyboards are a bit different
      # TODO: document exactly how
      if storyboard = container.dig?("playerLiveStoryboardSpecRenderer", "spec").try &.as_s
        return [Storyboard.new(
          url: URI.parse(storyboard.split("#")[0]),
          width: 106,
          height: 60,
          count: -1,
          interval: 5000,
          rows: 3,
          columns: 3,
          images_count: -1
        )]
      end

      # Split the storyboard string into chunks
      #
      # General format (whitespaces added for legibility):
      #   https://i.ytimg.com/sb/<video_id>/storyboard3_L$L/$N.jpg?sqp=<sig0>
      #   |  48 #  27 #  100 #  10 #  10 #      0 #  default #  rs$<sig1>
      #   |  80 #  45 #   95 #  10 #  10 #  10000 #      M$M #  rs$<sig2>
      #   | 160 #  90 #   95 #   5 #   5 #  10000 #      M$M #  rs$<sig3>
      #
      storyboards = container.dig?("playerStoryboardSpecRenderer", "spec")
        .try &.as_s.split("|")

      return [] of Storyboard if !storyboards

      # The base URL is the first chunk
      base_url = URI.parse(storyboards.shift)

      return storyboards.map_with_index do |sb, i|
        # Separate the different storyboard parameters:
        # width/height: respective dimensions, in pixels, of a single thumbnail
        # count: how many thumbnails are displayed across the full video
        # columns/rows: maximum amount of thumbnails that can be stuffed in a
        #   single image, horizontally and vertically.
        # interval: interval between two thumbnails, in milliseconds
        # name: storyboard filename. Usually "M$M" or "default"
        # sigh: URL cryptographic signature
        width, height, count, columns, rows, interval, name, sigh = sb.split("#")

        width = width.to_i
        height = height.to_i
        count = count.to_i
        interval = interval.to_i
        columns = columns.to_i
        rows = rows.to_i

        # Copy base URL object, so that we can modify it
        url = base_url.dup

        # Add the signature to the URL
        params = url.query_params
        params["sigh"] = sigh
        url.query_params = params

        # Replace the template parts with what we have
        url.path = url.path.sub("$L", i).sub("$N", name)

        # This value represents the maximum amount of thumbnails that can fit
        # in a single image. The last image (or the only one for short videos)
        # will contain less thumbnails than that.
        thumbnails_per_image = columns * rows

        # This value represents the total amount of storyboards required to
        # hold all of the thumbnails. It can't be less than 1.
        images_count = (count / thumbnails_per_image).ceil.to_i

        # Compute the interval when needed (in general, that's only required
        # for the first "default" storyboard).
        if interval == 0
          interval = ((length_seconds / count) * 1_000).to_i
        end

        Storyboard.new(
          url: url,
          width: width,
          height: height,
          count: count,
          interval: interval,
          rows: rows,
          columns: columns,
          images_count: images_count,
        )
      end
    end
  end
end
