enum VideoType
  Video
  Livestream
  Scheduled
end

struct Video
  include DB::Serializable

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

  @[DB::Field(converter: Video::JSONConverter)]
  property info : Hash(String, JSON::Any)
  property updated : Time

  @[DB::Field(ignore: true)]
  @captions = [] of Invidious::Videos::Captions::Metadata

  @[DB::Field(ignore: true)]
  property description : String?

  module JSONConverter
    def self.from_rs(rs)
      JSON.parse(rs.read(String)).as_h
    end
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

  def fmt_stream : Array(Hash(String, JSON::Any))
    if formats = info.dig?("streamingData", "formats")
      return formats
        .as_a.map(&.as_h)
        .sort_by! { |f| f["width"]?.try &.as_i || 0 }
    else
      return [] of Hash(String, JSON::Any)
    end
  end

  def adaptive_fmts : Array(Hash(String, JSON::Any))
    if formats = info.dig?("streamingData", "adaptiveFormats")
      return formats
        .as_a.map(&.as_h)
        .sort_by! { |f| f["width"]?.try &.as_i || 0 }
    else
      return [] of Hash(String, JSON::Any)
    end
  end

  def video_streams
    adaptive_fmts.select &.["mimeType"]?.try &.as_s.starts_with?("video")
  end

  def audio_streams
    adaptive_fmts.select &.["mimeType"]?.try &.as_s.starts_with?("audio")
  end

  # Misc. methods

  def storyboards
    container = info.dig?("storyboards") || JSON::Any.new("{}")
    return IV::Videos::Storyboard.from_yt_json(container, self.length_seconds)
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

  def vr? : Bool?
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

  # Macro to generate ? and = accessor methods for attributes in `info`
  private macro predicate_bool(method_name, name)
    # Return {{name.stringify}} from `info`
    def {{method_name.id.underscore}}? : Bool
      return info[{{name.stringify}}]?.try &.as_bool || false
    end

    # Update {{name.stringify}} into `info`
    def {{method_name.id.underscore}}=(value : Bool)
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

  # TODO: Make predicate_bool the default as to adhere to Crystal conventions
  getset_bool allowRatings
  getset_bool authorVerified
  getset_bool isFamilyFriendly
  getset_bool isListed
  predicate_bool upcoming, isUpcoming
end

def get_video(id, refresh = true, region = nil, force_refresh = false)
  if (video = Invidious::Database::Videos.select(id)) && !region
    # If record was last updated over 10 minutes ago, or video has since premiered,
    # refresh (expire param in response lasts for 6 hours)
    if (refresh &&
       (Time.utc - video.updated > 10.minutes) ||
       (video.premiere_timestamp.try &.< Time.utc)) ||
       force_refresh ||
       video.schema_version != Video::SCHEMA_VERSION # cache control
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
    Invidious::Database::Videos.insert(video) if !region && !video.info.dig?("reason")
  end

  return video
rescue DB::Error
  # Avoid common `DB::PoolRetryAttemptsExceeded` error and friends
  # Note: All DB errors inherit from `DB::Error`
  return fetch_video(id, region)
end

def fetch_video(id, region)
  info = extract_video_info(video_id: id)

  if info["reason"]? && info["subreason"]?
    reason = info["reason"].as_s
    puts info
    if info.dig?("subreason").nil?
      subreason = info["subreason"].as_s
    else
      subreason = "No additional reason"
    end
    if reason == "Video unavailable"
      raise NotFoundException.new(reason + ": Video not found" || "")
    elsif {"Private video"}.any?(reason)
      raise InfoException.new(reason + ": " + subreason || "")
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
