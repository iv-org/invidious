module YouTubeStructs
  # Converter to serialize first level JSON data as methods for the videos struct
  module VideoJSONConverter
    def self.from_rs(rs)
      JSON.parse(rs.read(String)).as_h
    end
  end

  # Represents an watchable video in Invidious
  #
  # The video struct only takes three parameters:
  # - ID: The video ID
  #
  # - Info:
  #  YT Video information (streams, captions, tiles, etc). This is then serialized
  #  into individual properties that either stores top level stuff or accesses
  #  further nested data.
  #
  # - Updated:
  #   A record of when the specific struct was created and inserted
  #  into the DB. This is then used to measure when to cache (or update)
  #  videos within the database.
  struct Video
    include DB::Serializable

    property id : String

    @[DB::Field(converter: YouTubeStructs::VideoJSONConverter)]
    property info : Hash(String, JSON::Any)
    property updated : Time

    @[DB::Field(ignore: true)]
    property captions : Array(Caption)?

    @[DB::Field(ignore: true)]
    property adaptive_fmts : Array(Hash(String, JSON::Any))?

    @[DB::Field(ignore: true)]
    property fmt_stream : Array(Hash(String, JSON::Any))?

    @[DB::Field(ignore: true)]
    property description : String?

    def to_json(locale : Hash(String, JSON::Any), json : JSON::Builder)
      json.object do
        json.field "type", "video"

        json.field "title", self.title
        json.field "videoId", self.id

        json.field "error", info["reason"] if info["reason"]?

        json.field "videoThumbnails" do
          generate_thumbnails(json, self.id)
        end
        json.field "storyboards" do
          generate_storyboards(json, self.id, self.storyboards)
        end

        json.field "description", self.description
        json.field "descriptionHtml", self.description_html
        json.field "published", self.published.to_unix
        json.field "publishedText", translate(locale, "`x` ago", recode_date(self.published, locale))
        json.field "keywords", self.keywords

        json.field "viewCount", self.views
        json.field "likeCount", self.likes
        json.field "dislikeCount", self.dislikes

        json.field "paid", self.paid
        json.field "premium", self.premium
        json.field "isFamilyFriendly", self.is_family_friendly
        json.field "allowedRegions", self.allowed_regions
        json.field "genre", self.genre
        json.field "genreUrl", self.genre_url

        json.field "author", self.author
        json.field "authorId", self.ucid
        json.field "authorUrl", "/channel/#{self.ucid}"

        json.field "authorThumbnails" do
          json.array do
            qualities = {32, 48, 76, 100, 176, 512}

            qualities.each do |quality|
              json.object do
                json.field "url", self.author_thumbnail.gsub(/=s\d+/, "=s#{quality}")
                json.field "width", quality
                json.field "height", quality
              end
            end
          end
        end

        json.field "subCountText", self.sub_count_text

        json.field "lengthSeconds", self.length_seconds
        json.field "allowRatings", self.allow_ratings
        json.field "rating", self.average_rating
        json.field "isListed", self.is_listed
        json.field "liveNow", self.live_now
        json.field "isUpcoming", self.is_upcoming

        if self.premiere_timestamp
          json.field "premiereTimestamp", self.premiere_timestamp.try &.to_unix
        end

        if hlsvp = self.hls_manifest_url
          hlsvp = hlsvp.gsub("https://manifest.googlevideo.com", HOST_URL)
          json.field "hlsUrl", hlsvp
        end

        json.field "dashUrl", "#{HOST_URL}/api/manifest/dash/id/#{id}"

        json.field "adaptiveFormats" do
          json.array do
            self.adaptive_fmts.each do |fmt|
              json.object do
                json.field "index", "#{fmt["indexRange"]["start"]}-#{fmt["indexRange"]["end"]}"
                json.field "bitrate", fmt["bitrate"].as_i.to_s
                json.field "init", "#{fmt["initRange"]["start"]}-#{fmt["initRange"]["end"]}"
                json.field "url", fmt["url"]
                json.field "itag", fmt["itag"].as_i.to_s
                json.field "type", fmt["mimeType"]
                json.field "clen", fmt["contentLength"]
                json.field "lmt", fmt["lastModified"]
                json.field "projectionType", fmt["projectionType"]

                fmt_info = itag_to_metadata?(fmt["itag"])
                if fmt_info
                  fps = fmt_info["fps"]?.try &.to_i || fmt["fps"]?.try &.as_i || 30
                  json.field "fps", fps
                  json.field "container", fmt_info["ext"]
                  json.field "encoding", fmt_info["vcodec"]? || fmt_info["acodec"]

                  if fmt_info["height"]?
                    json.field "resolution", "#{fmt_info["height"]}p"

                    quality_label = "#{fmt_info["height"]}p"
                    if fps > 30
                      quality_label += "60"
                    end
                    json.field "qualityLabel", quality_label

                    if fmt_info["width"]?
                      json.field "size", "#{fmt_info["width"]}x#{fmt_info["height"]}"
                    end
                  end
                end
              end
            end
          end
        end

        json.field "formatStreams" do
          json.array do
            self.fmt_stream.each do |fmt|
              json.object do
                json.field "url", fmt["url"]
                json.field "itag", fmt["itag"].as_i.to_s
                json.field "type", fmt["mimeType"]
                json.field "quality", fmt["quality"]

                fmt_info = itag_to_metadata?(fmt["itag"])
                if fmt_info
                  fps = fmt_info["fps"]?.try &.to_i || fmt["fps"]?.try &.as_i || 30
                  json.field "fps", fps
                  json.field "container", fmt_info["ext"]
                  json.field "encoding", fmt_info["vcodec"]? || fmt_info["acodec"]

                  if fmt_info["height"]?
                    json.field "resolution", "#{fmt_info["height"]}p"

                    quality_label = "#{fmt_info["height"]}p"
                    if fps > 30
                      quality_label += "60"
                    end
                    json.field "qualityLabel", quality_label

                    if fmt_info["width"]?
                      json.field "size", "#{fmt_info["width"]}x#{fmt_info["height"]}"
                    end
                  end
                end
              end
            end
          end
        end

        json.field "captions" do
          json.array do
            self.captions.each do |caption|
              json.object do
                json.field "label", caption.name
                json.field "language_code", caption.language_code
                json.field "url", "/api/v1/captions/#{id}?label=#{URI.encode_www_form(caption.name)}"
              end
            end
          end
        end

        json.field "recommendedVideos" do
          json.array do
            self.related_videos.each do |rv|
              if rv["id"]?
                json.object do
                  json.field "videoId", rv["id"]
                  json.field "title", rv["title"]
                  json.field "videoThumbnails" do
                    generate_thumbnails(json, rv["id"])
                  end

                  json.field "author", rv["author"]
                  json.field "authorUrl", rv["author_url"]?
                  json.field "authorId", rv["ucid"]?
                  if rv["author_thumbnail"]?
                    json.field "authorThumbnails" do
                      json.array do
                        qualities = {32, 48, 76, 100, 176, 512}

                        qualities.each do |quality|
                          json.object do
                            json.field "url", rv["author_thumbnail"]?.try &.gsub(/s\d+-/, "s#{quality}-")
                            json.field "width", quality
                            json.field "height", quality
                          end
                        end
                      end
                    end
                  end

                  json.field "lengthSeconds", rv["length_seconds"]?.try &.to_i
                  json.field "viewCountText", rv["short_view_count_text"]?
                  json.field "viewCount", rv["view_count"]?.try &.empty? ? nil : rv["view_count"].to_i64
                end
              end
            end
          end
        end
      end
    end

    def to_json(locale, json : JSON::Builder | Nil = nil)
      if json
        to_json(locale, json)
      else
        JSON.build do |json|
          to_json(locale, json)
        end
      end
    end

    def title
      info["videoDetails"]["title"]?.try &.as_s || ""
    end

    def ucid
      info["videoDetails"]["channelId"]?.try &.as_s || ""
    end

    def author
      info["videoDetails"]["author"]?.try &.as_s || ""
    end

    def length_seconds : Int32
      info["microformat"]?.try &.["playerMicroformatRenderer"]?.try &.["lengthSeconds"]?.try &.as_s.to_i ||
        info["videoDetails"]["lengthSeconds"]?.try &.as_s.to_i || 0
    end

    def views : Int64
      info["videoDetails"]["viewCount"]?.try &.as_s.to_i64 || 0_i64
    end

    def likes : Int64
      info["likes"]?.try &.as_i64 || 0_i64
    end

    def dislikes : Int64
      info["dislikes"]?.try &.as_i64 || 0_i64
    end

    def average_rating : Float64
      # (likes / (likes + dislikes) * 4 + 1)
      info["videoDetails"]["averageRating"]?.try { |t| t.as_f? || t.as_i64?.try &.to_f64 }.try &.round(4) || 0.0
    end

    def published : Time
      info["microformat"]?.try &.["playerMicroformatRenderer"]?.try &.["publishDate"]?.try { |t| Time.parse(t.as_s, "%Y-%m-%d", Time::Location::UTC) } || Time.utc
    end

    def published=(other : Time)
      info["microformat"].as_h["playerMicroformatRenderer"].as_h["publishDate"] = JSON::Any.new(other.to_s("%Y-%m-%d"))
    end

    def allow_ratings
      r = info["videoDetails"]["allowRatings"]?.try &.as_bool
      r.nil? ? false : r
    end

    def live_now
      info["microformat"]?.try &.["playerMicroformatRenderer"]?
        .try &.["liveBroadcastDetails"]?.try &.["isLiveNow"]?.try &.as_bool || false
    end

    def is_listed
      info["videoDetails"]["isCrawlable"]?.try &.as_bool || false
    end

    def is_upcoming
      info["videoDetails"]["isUpcoming"]?.try &.as_bool || false
    end

    def premiere_timestamp : Time?
      info["microformat"]?.try &.["playerMicroformatRenderer"]?
        .try &.["liveBroadcastDetails"]?.try &.["startTimestamp"]?.try { |t| Time.parse_rfc3339(t.as_s) }
    end

    def keywords
      info["videoDetails"]["keywords"]?.try &.as_a.map &.as_s || [] of String
    end

    def related_videos
      info["relatedVideos"]?.try &.as_a.map { |h| h.as_h.transform_values &.as_s } || [] of Hash(String, String)
    end

    def allowed_regions
      info["microformat"]?.try &.["playerMicroformatRenderer"]?
        .try &.["availableCountries"]?.try &.as_a.map &.as_s || [] of String
    end

    def author_thumbnail : String
      info["authorThumbnail"]?.try &.as_s || ""
    end

    def sub_count_text : String
      info["subCountText"]?.try &.as_s || "-"
    end

    def fmt_stream
      return @fmt_stream.as(Array(Hash(String, JSON::Any))) if @fmt_stream

      fmt_stream = info["streamingData"]?.try &.["formats"]?.try &.as_a.map &.as_h || [] of Hash(String, JSON::Any)
      fmt_stream.each do |fmt|
        if s = (fmt["cipher"]? || fmt["signatureCipher"]?).try { |h| HTTP::Params.parse(h.as_s) }
          s.each do |k, v|
            fmt[k] = JSON::Any.new(v)
          end
          fmt["url"] = JSON::Any.new("#{fmt["url"]}#{DECRYPT_FUNCTION.decrypt_signature(fmt)}")
        end

        fmt["url"] = JSON::Any.new("#{fmt["url"]}&host=#{URI.parse(fmt["url"].as_s).host}")
        fmt["url"] = JSON::Any.new("#{fmt["url"]}&region=#{self.info["region"]}") if self.info["region"]?
      end
      fmt_stream.sort_by! { |f| f["width"]?.try &.as_i || 0 }
      @fmt_stream = fmt_stream
      return @fmt_stream.as(Array(Hash(String, JSON::Any)))
    end

    def adaptive_fmts
      return @adaptive_fmts.as(Array(Hash(String, JSON::Any))) if @adaptive_fmts
      fmt_stream = info["streamingData"]?.try &.["adaptiveFormats"]?.try &.as_a.map &.as_h || [] of Hash(String, JSON::Any)
      fmt_stream.each do |fmt|
        if s = (fmt["cipher"]? || fmt["signatureCipher"]?).try { |h| HTTP::Params.parse(h.as_s) }
          s.each do |k, v|
            fmt[k] = JSON::Any.new(v)
          end
          fmt["url"] = JSON::Any.new("#{fmt["url"]}#{DECRYPT_FUNCTION.decrypt_signature(fmt)}")
        end

        fmt["url"] = JSON::Any.new("#{fmt["url"]}&host=#{URI.parse(fmt["url"].as_s).host}")
        fmt["url"] = JSON::Any.new("#{fmt["url"]}&region=#{self.info["region"]}") if self.info["region"]?
      end
      # See https://github.com/TeamNewPipe/NewPipe/issues/2415
      # Some streams are segmented by URL `sq/` rather than index, for now we just filter them out
      fmt_stream.reject! { |f| !f["indexRange"]? }
      fmt_stream.sort_by! { |f| f["width"]?.try &.as_i || 0 }
      @adaptive_fmts = fmt_stream
      return @adaptive_fmts.as(Array(Hash(String, JSON::Any)))
    end

    def video_streams
      adaptive_fmts.select &.["mimeType"]?.try &.as_s.starts_with?("video")
    end

    def audio_streams
      adaptive_fmts.select &.["mimeType"]?.try &.as_s.starts_with?("audio")
    end

    def storyboards
      storyboards = info["storyboards"]?
        .try &.as_h
          .try &.["playerStoryboardSpecRenderer"]?
            .try &.["spec"]?
              .try &.as_s.split("|")

      if !storyboards
        if storyboard = info["storyboards"]?
             .try &.as_h
               .try &.["playerLiveStoryboardSpecRenderer"]?
                 .try &.["spec"]?
                   .try &.as_s
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

      storyboards.each_with_index do |storyboard, i|
        width, height, count, storyboard_width, storyboard_height, interval, _, sigh = storyboard.split("#")
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

    def paid
      reason = info["playabilityStatus"]?.try &.["reason"]?
      paid = reason == "This video requires payment to watch." ? true : false
      paid
    end

    def premium
      keywords.includes? "YouTube Red"
    end

    def captions : Array(Caption)
      return @captions.as(Array(Caption)) if @captions
      captions = info["captions"]?.try &.["playerCaptionsTracklistRenderer"]?.try &.["captionTracks"]?.try &.as_a.map do |caption|
        name = caption["name"]["simpleText"]? || caption["name"]["runs"][0]["text"]
        language_code = caption["languageCode"].to_s
        base_url = caption["baseUrl"].to_s

        caption = Caption.new(name.to_s, language_code, base_url)
        caption.name = caption.name.split(" - ")[0]
        caption
      end
      captions ||= [] of Caption
      @captions = captions
      return @captions.as(Array(Caption))
    end

    def description
      description = info["microformat"]?.try &.["playerMicroformatRenderer"]?
        .try &.["description"]?.try &.["simpleText"]?.try &.as_s || ""
    end

    # TODO
    def description=(value : String)
      @description = value
    end

    def description_html
      info["descriptionHtml"]?.try &.as_s || "<p></p>"
    end

    def description_html=(value : String)
      info["descriptionHtml"] = JSON::Any.new(value)
    end

    def short_description
      info["shortDescription"]?.try &.as_s? || ""
    end

    def hls_manifest_url : String?
      info["streamingData"]?.try &.["hlsManifestUrl"]?.try &.as_s
    end

    def dash_manifest_url
      info["streamingData"]?.try &.["dashManifestUrl"]?.try &.as_s
    end

    def genre : String
      info["genre"]?.try &.as_s || ""
    end

    def genre_url : String?
      info["genreUcid"]? ? "/channel/#{info["genreUcid"]}" : nil
    end

    def license : String?
      info["license"]?.try &.as_s
    end

    def is_family_friendly : Bool
      info["microformat"]?.try &.["playerMicroformatRenderer"]["isFamilySafe"]?.try &.as_bool || false
    end

    def is_vr : Bool?
      projection_type = info.dig?("streamingData", "adaptiveFormats", 0, "projectionType").try &.as_s
      return {"EQUIRECTANGULAR", "MESH"}.includes? projection_type
    end

    def projection_type : String?
      return info.dig?("streamingData", "adaptiveFormats", 0, "projectionType").try &.as_s
    end

    def wilson_score : Float64
      ci_lower_bound(likes, likes + dislikes).round(4)
    end

    def engagement : Float64
      (((likes + dislikes) / views) * 100).round(4)
    end

    def reason : String?
      info["reason"]?.try &.as_s
    end
  end
end
