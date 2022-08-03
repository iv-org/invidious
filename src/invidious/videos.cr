enum VideoType
  Video
  Livestream
  Scheduled
end

struct Video
  include DB::Serializable

  property id : String

  @[DB::Field(converter: Video::JSONConverter)]
  property info : Hash(String, JSON::Any)
  property updated : Time

  @[DB::Field(ignore: true)]
  @captions = [] of Invidious::Videos::Caption

  @[DB::Field(ignore: true)]
  property adaptive_fmts : Array(Hash(String, JSON::Any))?

  @[DB::Field(ignore: true)]
  property fmt_stream : Array(Hash(String, JSON::Any))?

  @[DB::Field(ignore: true)]
  property description : String?

  module JSONConverter
    def self.from_rs(rs)
      JSON.parse(rs.read(String)).as_h
    end
  end

  def to_json(locale : String?, json : JSON::Builder)
    json.object do
      json.field "type", self.video_type

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
      json.field "dislikeCount", 0_i64

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
      json.field "rating", 0_i64
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
              # Only available on regular videos, not livestreams/OTF streams
              if init_range = fmt["initRange"]?
                json.field "init", "#{init_range["start"]}-#{init_range["end"]}"
              end
              if index_range = fmt["indexRange"]?
                json.field "index", "#{index_range["start"]}-#{index_range["end"]}"
              end

              # Not available on MPEG-4 Timed Text (`text/mp4`) streams (livestreams only)
              json.field "bitrate", fmt["bitrate"].as_i.to_s if fmt["bitrate"]?

              json.field "url", fmt["url"]
              json.field "itag", fmt["itag"].as_i.to_s
              json.field "type", fmt["mimeType"]
              json.field "clen", fmt["contentLength"]? || "-1"
              json.field "lmt", fmt["lastModified"]
              json.field "projectionType", fmt["projectionType"]

              if fmt_info = Invidious::Videos::Formats.itag_to_metadata?(fmt["itag"])
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

              # Livestream chunk infos
              json.field "targetDurationSec", fmt["targetDurationSec"].as_i if fmt.has_key?("targetDurationSec")
              json.field "maxDvrDurationSec", fmt["maxDvrDurationSec"].as_i if fmt.has_key?("maxDvrDurationSec")

              # Audio-related data
              json.field "audioQuality", fmt["audioQuality"] if fmt.has_key?("audioQuality")
              json.field "audioSampleRate", fmt["audioSampleRate"].as_s.to_i if fmt.has_key?("audioSampleRate")
              json.field "audioChannels", fmt["audioChannels"] if fmt.has_key?("audioChannels")

              # Extra misc stuff
              json.field "colorInfo", fmt["colorInfo"] if fmt.has_key?("colorInfo")
              json.field "captionTrack", fmt["captionTrack"] if fmt.has_key?("captionTrack")
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

              fmt_info = Invidious::Videos::Formats.itag_to_metadata?(fmt["itag"])
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
                json.field "authorUrl", "/channel/#{rv["ucid"]?}"
                json.field "authorId", rv["ucid"]?
                if rv["author_thumbnail"]?
                  json.field "authorThumbnails" do
                    json.array do
                      qualities = {32, 48, 76, 100, 176, 512}

                      qualities.each do |quality|
                        json.object do
                          json.field "url", rv["author_thumbnail"].gsub(/s\d+-/, "s#{quality}-")
                          json.field "width", quality
                          json.field "height", quality
                        end
                      end
                    end
                  end
                end

                json.field "lengthSeconds", rv["length_seconds"]?.try &.to_i
                json.field "viewCountText", rv["short_view_count"]?
                json.field "viewCount", rv["view_count"]?.try &.empty? ? nil : rv["view_count"].to_i64
              end
            end
          end
        end
      end
    end
  end

  # TODO: remove the locale and follow the crystal convention
  def to_json(locale : String?, _json : Nil)
    JSON.build { |json| to_json(locale, json) }
  end

  def to_json(json : JSON::Builder | Nil = nil)
    to_json(nil, json)
  end

  def video_type : VideoType
    video_type = info["videoType"]?.try &.as_s || "video"
    return VideoType.parse?(video_type) || VideoType::Video
  end

  def published : Time
    return info["published"]?
      .try { |t| Time.parse(t.as_s, "%Y-%m-%d", Time::Location::UTC) } || Time.utc
  end

  def published=(other : Time)
    info["published"] = JSON::Any.new(other.to_s("%Y-%m-%d"))
  end

  def live_now
    return (self.video_type == VideoType::Livestream)
  end

  def premiere_timestamp : Time?
    info
      .dig?("microformat", "playerMicroformatRenderer", "liveBroadcastDetails", "startTimestamp")
      .try { |t| Time.parse_rfc3339(t.as_s) }
  end

  def related_videos
    info["relatedVideos"]?.try &.as_a.map { |h| h.as_h.transform_values &.as_s } || [] of Hash(String, String)
  end

  # Methods for parsing streaming data

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

  # Misc. methods

  def storyboards
    storyboards = info.dig?("storyboards", "playerStoryboardSpecRenderer", "spec")
      .try &.as_s.split("|")

    if !storyboards
      if storyboard = info.dig?("storyboards", "playerLiveStoryboardSpecRenderer", "spec").try &.as_s
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

  def paid
    return (self.reason || "").includes? "requires payment"
  end

  def premium
    keywords.includes? "YouTube Red"
  end

  def captions : Array(Invidious::Videos::Caption)
    if @captions.empty? && @info.has_key?("captions")
      @captions = Invidious::Videos::Caption.from_yt_json(info["captions"])
    end

    return @captions
  end

  def hls_manifest_url : String?
    info.dig?("streamingData", "hlsManifestUrl").try &.as_s
  end

  def dash_manifest_url
    info.dig?("streamingData", "dashManifestUrl").try &.as_s
  end

  def genre_url : String?
    info["genreUcid"]? ? "/channel/#{info["genreUcid"]}" : nil
  end

  def is_vr : Bool?
    return {"EQUIRECTANGULAR", "MESH"}.includes? self.projection_type
  end

  def projection_type : String?
    return info.dig?("streamingData", "adaptiveFormats", 0, "projectionType").try &.as_s
  end

  def reason : String?
    info["reason"]?.try &.as_s
  end

  # Macros defining getters/setters for various types of data

  private macro getset_string(name)
    # Return {{name.stringify}} from `info`
    def {{name.id.underscore}} : String
      return info[{{name.stringify}}]?.try &.as_s || ""
    end

    # Update {{name.stringify}} into `info`
    def {{name.id.underscore}}=(value : String)
      info[{{name.stringify}}] = JSON::Any.new(value)
    end

    {% if flag?(:debug_macros) %} {{debug}} {% end %}
  end

  private macro getset_string_array(name)
    # Return {{name.stringify}} from `info`
    def {{name.id.underscore}} : Array(String)
      return info[{{name.stringify}}]?.try &.as_a.map &.as_s || [] of String
    end

    # Update {{name.stringify}} into `info`
    def {{name.id.underscore}}=(value : Array(String))
      info[{{name.stringify}}] = JSON::Any.new(value)
    end

    {% if flag?(:debug_macros) %} {{debug}} {% end %}
  end

  {% for op, type in {i32: Int32, i64: Int64} %}
    private macro getset_{{op}}(name)
      def \{{name.id.underscore}} : {{type}}
        return info[\{{name.stringify}}]?.try &.as_i.to_{{op}} || 0_{{op}}
      end

      def \{{name.id.underscore}}=(value : Int)
        info[\{{name.stringify}}] = JSON::Any.new(value.to_i64)
      end

      \{% if flag?(:debug_macros) %} \{{debug}} \{% end %}
    end
  {% end %}

  private macro getset_bool(name)
    # Return {{name.stringify}} from `info`
    def {{name.id.underscore}} : Bool
      return info[{{name.stringify}}]?.try &.as_bool || false
    end

    # Update {{name.stringify}} into `info`
    def {{name.id.underscore}}=(value : Bool)
      info[{{name.stringify}}] = JSON::Any.new(value)
    end

    {% if flag?(:debug_macros) %} {{debug}} {% end %}
  end

  # Method definitions, using the macros above

  getset_string author
  getset_string authorThumbnail
  getset_string description
  getset_string descriptionHtml
  getset_string genre
  getset_string genreUcid
  getset_string license
  getset_string shortDescription
  getset_string subCountText
  getset_string title
  getset_string ucid

  getset_string_array allowedRegions
  getset_string_array keywords

  getset_i32 lengthSeconds
  getset_i64 likes
  getset_i64 views

  getset_bool allowRatings
  getset_bool authorVerified
  getset_bool isFamilyFriendly
  getset_bool isListed
  getset_bool isUpcoming
end

class VideoRedirect < Exception
  property video_id : String

  def initialize(@video_id)
  end
end

# Use to parse both "compactVideoRenderer" and "endScreenVideoRenderer".
# The former is preferred as it has more videos in it. The second has
# the same 11 first entries as the compact rendered.
#
# TODO: "compactRadioRenderer" (Mix) and
# TODO: Use a proper struct/class instead of a hacky JSON object
def parse_related_video(related : JSON::Any) : Hash(String, JSON::Any)?
  return nil if !related["videoId"]?

  # The compact renderer has video length in seconds, where the end
  # screen rendered has a full text version ("42:40")
  length = related["lengthInSeconds"]?.try &.as_i.to_s
  length ||= related.dig?("lengthText", "simpleText").try do |box|
    decode_length_seconds(box.as_s).to_s
  end

  # Both have "short", so the "long" option shouldn't be required
  channel_info = (related["shortBylineText"]? || related["longBylineText"]?)
    .try &.dig?("runs", 0)

  author = channel_info.try &.dig?("text")
  author_verified = has_verified_badge?(related["ownerBadges"]?).to_s

  ucid = channel_info.try { |ci| HelperExtractors.get_browse_id(ci) }

  # "4,088,033 views", only available on compact renderer
  # and when video is not a livestream
  view_count = related.dig?("viewCountText", "simpleText")
    .try &.as_s.gsub(/\D/, "")

  short_view_count = related.try do |r|
    HelperExtractors.get_short_view_count(r).to_s
  end

  LOGGER.trace("parse_related_video: Found \"watchNextEndScreenRenderer\" container")

  # TODO: when refactoring video types, make a struct for related videos
  # or reuse an existing type, if that fits.
  return {
    "id"               => related["videoId"],
    "title"            => related["title"]["simpleText"],
    "author"           => author || JSON::Any.new(""),
    "ucid"             => JSON::Any.new(ucid || ""),
    "length_seconds"   => JSON::Any.new(length || "0"),
    "view_count"       => JSON::Any.new(view_count || "0"),
    "short_view_count" => JSON::Any.new(short_view_count || "0"),
    "author_verified"  => JSON::Any.new(author_verified),
  }
end

def extract_video_info(video_id : String, proxy_region : String? = nil, context_screen : String? = nil)
  # Init client config for the API
  client_config = YoutubeAPI::ClientConfig.new(proxy_region: proxy_region)
  if context_screen == "embed"
    client_config.client_type = YoutubeAPI::ClientType::TvHtml5ScreenEmbed
  end

  # Fetch data from the player endpoint
  player_response = YoutubeAPI.player(video_id: video_id, params: "", client_config: client_config)

  playability_status = player_response.dig?("playabilityStatus", "status").try &.as_s

  if playability_status != "OK"
    subreason = player_response.dig?("playabilityStatus", "errorScreen", "playerErrorMessageRenderer", "subreason")
    reason = subreason.try &.[]?("simpleText").try &.as_s
    reason ||= subreason.try &.[]("runs").as_a.map(&.[]("text")).join("")
    reason ||= player_response.dig("playabilityStatus", "reason").as_s

    # Stop here if video is not a scheduled livestream
    if playability_status != "LIVE_STREAM_OFFLINE"
      return {
        "reason" => JSON::Any.new(reason),
      }
    end
  elsif video_id != player_response.dig("videoDetails", "videoId")
    # YouTube may return a different video player response than expected.
    # See: https://github.com/TeamNewPipe/NewPipe/issues/8713
    raise VideoNotAvailableException.new("The video returned by YouTube isn't the requested one. (WEB client)")
  else
    reason = nil
  end

  # Don't fetch the next endpoint if the video is unavailable.
  if {"OK", "LIVE_STREAM_OFFLINE"}.any?(playability_status)
    next_response = YoutubeAPI.next({"videoId": video_id, "params": ""})
    player_response = player_response.merge(next_response)
  end

  params = parse_video_info(video_id, player_response)
  params["reason"] = JSON::Any.new(reason) if reason

  # Fetch the video streams using an Android client in order to get the decrypted URLs and
  # maybe fix throttling issues (#2194).See for the explanation about the decrypted URLs:
  # https://github.com/TeamNewPipe/NewPipeExtractor/issues/562
  if reason.nil?
    if context_screen == "embed"
      client_config.client_type = YoutubeAPI::ClientType::AndroidScreenEmbed
    else
      client_config.client_type = YoutubeAPI::ClientType::Android
    end
    android_player = YoutubeAPI.player(video_id: video_id, params: "", client_config: client_config)

    # Sometimes, the video is available from the web client, but not on Android, so check
    # that here, and fallback to the streaming data from the web client if needed.
    # See: https://github.com/iv-org/invidious/issues/2549
    if video_id != android_player.dig("videoDetails", "videoId")
      # YouTube may return a different video player response than expected.
      # See: https://github.com/TeamNewPipe/NewPipe/issues/8713
      raise VideoNotAvailableException.new("The video returned by YouTube isn't the requested one. (ANDROID client)")
    elsif android_player["playabilityStatus"]["status"] == "OK"
      params["streamingData"] = android_player["streamingData"]? || JSON::Any.new("")
    else
      params["streamingData"] = player_response["streamingData"]? || JSON::Any.new("")
    end
  end

  # TODO: clean that up
  {"captions", "microformat", "playabilityStatus", "storyboards", "videoDetails"}.each do |f|
    params[f] = player_response[f] if player_response[f]?
  end

  return params
end

def parse_video_info(video_id : String, player_response : Hash(String, JSON::Any)) : Hash(String, JSON::Any)
  # Top level elements

  main_results = player_response.dig?("contents", "twoColumnWatchNextResults")

  raise BrokenTubeException.new("twoColumnWatchNextResults") if !main_results

  primary_results = main_results.dig?("results", "results", "contents")

  raise BrokenTubeException.new("results") if !primary_results

  video_primary_renderer = primary_results
    .as_a.find(&.["videoPrimaryInfoRenderer"]?)
    .try &.["videoPrimaryInfoRenderer"]

  video_secondary_renderer = primary_results
    .as_a.find(&.["videoSecondaryInfoRenderer"]?)
    .try &.["videoSecondaryInfoRenderer"]

  raise BrokenTubeException.new("videoPrimaryInfoRenderer") if !video_primary_renderer
  raise BrokenTubeException.new("videoSecondaryInfoRenderer") if !video_secondary_renderer

  video_details = player_response.dig?("videoDetails")
  microformat = player_response.dig?("microformat", "playerMicroformatRenderer")

  raise BrokenTubeException.new("videoDetails") if !video_details
  raise BrokenTubeException.new("microformat") if !microformat

  # Basic video infos

  title = video_details["title"]?.try &.as_s

  views = video_primary_renderer
    .dig?("viewCount", "videoViewCountRenderer", "viewCount", "runs", 0, "text")
    .try &.as_s.to_i64
  views ||= video_details["viewCount"]?.try &.as_s.to_i64

  length_txt = (microformat["lengthSeconds"]? || video_details["lengthSeconds"])
    .try &.as_s.to_i64

  published = microformat["publishDate"]?
    .try { |t| Time.parse(t.as_s, "%Y-%m-%d", Time::Location::UTC) } || Time.utc

  premiere_timestamp = microformat.dig?("liveBroadcastDetails", "startTimestamp")
    .try { |t| Time.parse_rfc3339(t.as_s) }

  live_now = microformat.dig?("liveBroadcastDetails", "isLiveNow")
    .try &.as_bool || false

  # Extra video infos

  allowed_regions = microformat["availableCountries"]?
    .try &.as_a.map &.as_s || [] of String

  allow_ratings = video_details["allowRatings"]?.try &.as_bool
  family_friendly = microformat["isFamilySafe"].try &.as_bool
  is_listed = video_details["isCrawlable"]?.try &.as_bool
  is_upcoming = video_details["isUpcoming"]?.try &.as_bool

  keywords = video_details["keywords"]?
    .try &.as_a.map &.as_s || [] of String

  # Related videos

  LOGGER.debug("extract_video_info: parsing related videos...")

  related = [] of JSON::Any

  # Parse "compactVideoRenderer" items (under secondary results)
  secondary_results = main_results
    .dig?("secondaryResults", "secondaryResults", "results")
  secondary_results.try &.as_a.each do |element|
    if item = element["compactVideoRenderer"]?
      related_video = parse_related_video(item)
      related << JSON::Any.new(related_video) if related_video
    end
  end

  # If nothing was found previously, fall back to end screen renderer
  if related.empty?
    # Container for "endScreenVideoRenderer" items
    player_overlays = player_response.dig?(
      "playerOverlays", "playerOverlayRenderer",
      "endScreen", "watchNextEndScreenRenderer", "results"
    )

    player_overlays.try &.as_a.each do |element|
      if item = element["endScreenVideoRenderer"]?
        related_video = parse_related_video(item)
        related << JSON::Any.new(related_video) if related_video
      end
    end
  end

  # Likes

  toplevel_buttons = video_primary_renderer
    .try &.dig?("videoActions", "menuRenderer", "topLevelButtons")

  if toplevel_buttons
    likes_button = toplevel_buttons.as_a
      .find(&.dig?("toggleButtonRenderer", "defaultIcon", "iconType").=== "LIKE")
      .try &.["toggleButtonRenderer"]

    if likes_button
      likes_txt = (likes_button["defaultText"]? || likes_button["toggledText"]?)
        .try &.dig?("accessibility", "accessibilityData", "label")
      likes = likes_txt.as_s.gsub(/\D/, "").to_i64? if likes_txt

      LOGGER.trace("extract_video_info: Found \"likes\" button. Button text is \"#{likes_txt}\"")
      LOGGER.debug("extract_video_info: Likes count is #{likes}") if likes
    end
  end

  # Description

  description = microformat.dig?("description", "simpleText").try &.as_s || ""
  short_description = player_response.dig?("videoDetails", "shortDescription")

  description_html = video_secondary_renderer.try &.dig?("description", "runs")
    .try &.as_a.try { |t| content_to_comment_html(t, video_id) }

  # Video metadata

  metadata = video_secondary_renderer
    .try &.dig?("metadataRowContainer", "metadataRowContainerRenderer", "rows")
      .try &.as_a

  genre = microformat["category"]?
  genre_ucid = nil
  license = nil

  metadata.try &.each do |row|
    metadata_title = row.dig?("metadataRowRenderer", "title", "simpleText").try &.as_s
    contents = row.dig?("metadataRowRenderer", "contents", 0)

    if metadata_title == "Category"
      contents = contents.try &.dig?("runs", 0)

      genre = contents.try &.["text"]?
      genre_ucid = contents.try &.dig?("navigationEndpoint", "browseEndpoint", "browseId")
    elsif metadata_title == "License"
      license = contents.try &.dig?("runs", 0, "text")
    elsif metadata_title == "Licensed to YouTube by"
      license = contents.try &.["simpleText"]?
    end
  end

  # Author infos

  author = video_details["author"]?.try &.as_s
  ucid = video_details["channelId"]?.try &.as_s

  if author_info = video_secondary_renderer.try &.dig?("owner", "videoOwnerRenderer")
    author_thumbnail = author_info.dig?("thumbnail", "thumbnails", 0, "url")
    author_verified = has_verified_badge?(author_info["badges"]?)

    subs_text = author_info["subscriberCountText"]?
      .try { |t| t["simpleText"]? || t.dig?("runs", 0, "text") }
      .try &.as_s.split(" ", 2)[0]
  end

  # Return data

  if live_now
    video_type = VideoType::Livestream
  elsif premiere_timestamp.not_nil!
    video_type = VideoType::Scheduled
    published = premiere_timestamp || Time.utc
  else
    video_type = VideoType::Video
  end

  params = {
    "videoType" => JSON::Any.new(video_type.to_s),
    # Basic video infos
    "title"         => JSON::Any.new(title || ""),
    "views"         => JSON::Any.new(views || 0_i64),
    "likes"         => JSON::Any.new(likes || 0_i64),
    "lengthSeconds" => JSON::Any.new(length_txt || 0_i64),
    "published"     => JSON::Any.new(published.to_rfc3339),
    # Extra video infos
    "allowedRegions"   => JSON::Any.new(allowed_regions.map { |v| JSON::Any.new(v) }),
    "allowRatings"     => JSON::Any.new(allow_ratings || false),
    "isFamilyFriendly" => JSON::Any.new(family_friendly || false),
    "isListed"         => JSON::Any.new(is_listed || false),
    "isUpcoming"       => JSON::Any.new(is_upcoming || false),
    "keywords"         => JSON::Any.new(keywords.map { |v| JSON::Any.new(v) }),
    # Related videos
    "relatedVideos" => JSON::Any.new(related),
    # Description
    "description"      => JSON::Any.new(description || ""),
    "descriptionHtml"  => JSON::Any.new(description_html || "<p></p>"),
    "shortDescription" => JSON::Any.new(short_description.try &.as_s || nil),
    # Video metadata
    "genre"     => JSON::Any.new(genre.try &.as_s || ""),
    "genreUcid" => JSON::Any.new(genre_ucid.try &.as_s || ""),
    "license"   => JSON::Any.new(license.try &.as_s || ""),
    # Author infos
    "author"          => JSON::Any.new(author || ""),
    "ucid"            => JSON::Any.new(ucid || ""),
    "authorThumbnail" => JSON::Any.new(author_thumbnail.try &.as_s || ""),
    "authorVerified"  => JSON::Any.new(author_verified),
    "subCountText"    => JSON::Any.new(subs_text || "-"),
  }

  return params
end

def get_video(id, refresh = true, region = nil, force_refresh = false)
  if (video = Invidious::Database::Videos.select(id)) && !region
    # If record was last updated over 10 minutes ago, or video has since premiered,
    # refresh (expire param in response lasts for 6 hours)
    if (refresh &&
       (Time.utc - video.updated > 10.minutes) ||
       (video.premiere_timestamp.try &.< Time.utc)) ||
       force_refresh
      begin
        video = fetch_video(id, region)
        Invidious::Database::Videos.update(video)
      rescue ex
        Invidious::Database::Videos.delete(id)
        raise ex
      end
    end
  else
    video = fetch_video(id, region)
    Invidious::Database::Videos.insert(video) if !region
  end

  return video
rescue DB::Error
  # Avoid common `DB::PoolRetryAttemptsExceeded` error and friends
  # Note: All DB errors inherit from `DB::Error`
  return fetch_video(id, region)
end

def fetch_video(id, region)
  info = extract_video_info(video_id: id)

  allowed_regions = info
    .dig?("microformat", "playerMicroformatRenderer", "availableCountries")
    .try &.as_a.map &.as_s || [] of String

  # Check for region-blocks
  if info["reason"]?.try &.as_s.includes?("your country")
    bypass_regions = PROXY_LIST.keys & allowed_regions
    if !bypass_regions.empty?
      region = bypass_regions[rand(bypass_regions.size)]
      region_info = extract_video_info(video_id: id, proxy_region: region)
      region_info["region"] = JSON::Any.new(region) if region
      info = region_info if !region_info["reason"]?
    end
  end

  # Try to fetch video info using an embedded client
  if info["reason"]?
    embed_info = extract_video_info(video_id: id, context_screen: "embed")
    info = embed_info if !embed_info["reason"]?
  end

  if reason = info["reason"]?
    if reason == "Video unavailable"
      raise NotFoundException.new(reason.as_s || "")
    else
      raise InfoException.new(reason.as_s || "")
    end
  end

  video = Video.new({
    id:      id,
    info:    info,
    updated: Time.utc,
  })

  return video
end

def process_continuation(query, plid, id)
  continuation = nil
  if plid
    if index = query["index"]?.try &.to_i?
      continuation = index
    else
      continuation = id
    end
    continuation ||= 0
  end

  continuation
end

def build_thumbnails(id)
  return {
    {host: HOST_URL, height: 720, width: 1280, name: "maxres", url: "maxres"},
    {host: HOST_URL, height: 720, width: 1280, name: "maxresdefault", url: "maxresdefault"},
    {host: HOST_URL, height: 480, width: 640, name: "sddefault", url: "sddefault"},
    {host: HOST_URL, height: 360, width: 480, name: "high", url: "hqdefault"},
    {host: HOST_URL, height: 180, width: 320, name: "medium", url: "mqdefault"},
    {host: HOST_URL, height: 90, width: 120, name: "default", url: "default"},
    {host: HOST_URL, height: 90, width: 120, name: "start", url: "1"},
    {host: HOST_URL, height: 90, width: 120, name: "middle", url: "2"},
    {host: HOST_URL, height: 90, width: 120, name: "end", url: "3"},
  }
end

def generate_thumbnails(json, id)
  json.array do
    build_thumbnails(id).each do |thumbnail|
      json.object do
        json.field "quality", thumbnail[:name]
        json.field "url", "#{thumbnail[:host]}/vi/#{id}/#{thumbnail["url"]}.jpg"
        json.field "width", thumbnail[:width]
        json.field "height", thumbnail[:height]
      end
    end
  end
end

def generate_storyboards(json, id, storyboards)
  json.array do
    storyboards.each do |storyboard|
      json.object do
        json.field "url", "/api/v1/storyboards/#{id}?width=#{storyboard[:width]}&height=#{storyboard[:height]}"
        json.field "templateUrl", storyboard[:url]
        json.field "width", storyboard[:width]
        json.field "height", storyboard[:height]
        json.field "count", storyboard[:count]
        json.field "interval", storyboard[:interval]
        json.field "storyboardWidth", storyboard[:storyboard_width]
        json.field "storyboardHeight", storyboard[:storyboard_height]
        json.field "storyboardCount", storyboard[:storyboard_count]
      end
    end
  end
end
