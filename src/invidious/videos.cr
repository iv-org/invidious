enum VideoType
  Video
  Livestream
  Scheduled
end

struct Video
  # Version of the JSON structure
  # It prevents us from loading an incompatible version from cache
  # (either newer or older, if instances with different versions run
  # concurrently, e.g during a version upgrade rollout).
  #
  # NOTE: don't forget to bump this number if any change is made to
  # the `params` structure in videos/parser.cr!!!
  #
  SCHEMA_VERSION = 2

  property id : String
  property info : Hash(String, JSON::Any)

  @captions = [] of Invidious::Videos::Captions::Metadata

  property adaptive_fmts : Array(Hash(String, JSON::Any))?
  property fmt_stream : Array(Hash(String, JSON::Any))?

  property description : String?

  module JSONConverter
    def self.from_rs(rs)
      JSON.parse(rs.read(String)).as_h
    end
  end

  # Create new object from cache (JSON)
  def initialize(@id, @info)
  end

  def self.get(id : String, *, force_refresh = false, region = nil)
    key = "video:#{id}"
    key += ":#{region}" if !region.nil?

    # Fetch video from cache, unles a force refresh is requested
    info = force_refresh ? nil : IV::Cache::INSTANCE.fetch(key)
    updated = false

    # Fetch video from youtube, if needed
    if info.nil?
      video = Video.new(id, fetch_video(id, region))
      updated = true
    else
      video = Video.new(id, JSON.parse(info).as_h)

      # If video has premiered, live has started or the format
      # of the video data has changed, refresh the data.
      outdated_data = (video.schema_version != Video::SCHEMA_VERSION)
      live_started = (video.live_now && video.published < Time.utc)

      if outdated_data || live_started
        video = Video.new(id, fetch_video(id, region))
        updated = true
      end
    end

    # Store updated entry in cache
    # TODO: finer cache control based on video type & publication date
    if updated
      if video.live_now || video.published < Time.utc
        IV::Cache::INSTANCE.store(key, info.to_json, 10.minutes)
      else
        IV::Cache::INSTANCE.store(key, info.to_json, 2.hours)
      end
    end

    return video
  end

  # Methods for API v1 JSON

  def to_json(locale : String?, json : JSON::Builder)
    Invidious::JSONify::APIv1.video(self, json, locale: locale)
  end

  # TODO: remove the locale and follow the crystal convention
  def to_json(locale : String?, _json : Nil)
    JSON.build do |json|
      Invidious::JSONify::APIv1.video(self, json, locale: locale)
    end
  end

  def to_json(json : JSON::Builder | Nil = nil)
    to_json(nil, json)
  end

  # Misc methods

  def video_type : VideoType
    video_type = info["videoType"]?.try &.as_s || "video"
    return VideoType.parse?(video_type) || VideoType::Video
  end

  def schema_version : Int
    return info["version"]?.try &.as_i || 1
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

  def post_live_dvr
    return info["isPostLiveDvr"].as_bool
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

  def captions : Array(Invidious::Videos::Captions::Metadata)
    if @captions.empty? && @info.has_key?("captions")
      @captions = Invidious::Videos::Captions::Metadata.from_yt_json(info["captions"])
    end

    return @captions
  end

  def hls_manifest_url : String?
    info.dig?("streamingData", "hlsManifestUrl").try &.as_s
  end

  def dash_manifest_url : String?
    raw_dash_url = info.dig?("streamingData", "dashManifestUrl").try &.as_s
    return nil if raw_dash_url.nil?

    # Use manifest v5 parameter to reduce file size
    # See https://github.com/iv-org/invidious/issues/4186
    dash_url = URI.parse(raw_dash_url)
    dash_query = dash_url.query || ""

    if dash_query.empty?
      dash_url.path = "#{dash_url.path}/mpd_version/5"
    else
      dash_url.query = "#{dash_query}&mpd_version=5"
    end

    return dash_url.to_s
  end

  def genre_url : String?
    info["genreUcid"].try &.as_s? ? "/channel/#{info["genreUcid"]}" : nil
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

  def music : Array(VideoMusic)
    info["music"].as_a.map { |music_json|
      VideoMusic.new(
        music_json["song"].as_s,
        music_json["album"].as_s,
        music_json["artist"].as_s,
        music_json["license"].as_s
      )
    }
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
        return info[\{{name.stringify}}]?.try &.as_i64.to_{{op}} || 0_{{op}}
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

def fetch_video(id, region)
  info = extract_video_info(video_id: id)

  allowed_regions = info
    .dig?("microformat", "playerMicroformatRenderer", "availableCountries")
    .try &.as_a.map &.as_s || [] of String

  if reason = info["reason"]?
    if reason == "Video unavailable"
      raise NotFoundException.new(reason.as_s || "")
    elsif !reason.as_s.starts_with? "Premieres"
      # dont error when it's a premiere.
      # we already parsed most of the data and display the premiere date
      raise InfoException.new(reason.as_s || "")
    end
  end

  return info
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
