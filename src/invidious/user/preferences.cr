#
# This file contains the user preferences data structures and
# all the associated validation/parsing routines.
#

struct Preferences
  include JSON::Serializable
  include YAML::Serializable

  property annotations : Bool = CONFIG.default_user_preferences.annotations
  property annotations_subscribed : Bool = CONFIG.default_user_preferences.annotations_subscribed
  property autoplay : Bool = CONFIG.default_user_preferences.autoplay
  property automatic_instance_redirect : Bool = CONFIG.default_user_preferences.automatic_instance_redirect

  @[JSON::Field(converter: Preferences::StringToArray)]
  @[YAML::Field(converter: Preferences::StringToArray)]
  property captions : Array(String) = CONFIG.default_user_preferences.captions

  @[JSON::Field(converter: Preferences::StringToArray)]
  @[YAML::Field(converter: Preferences::StringToArray)]
  property comments : Array(String) = CONFIG.default_user_preferences.comments
  property continue : Bool = CONFIG.default_user_preferences.continue
  property continue_autoplay : Bool = CONFIG.default_user_preferences.continue_autoplay

  @[JSON::Field(converter: Preferences::BoolToString)]
  @[YAML::Field(converter: Preferences::BoolToString)]
  property dark_mode : String = CONFIG.default_user_preferences.dark_mode
  property latest_only : Bool = CONFIG.default_user_preferences.latest_only
  property listen : Bool = CONFIG.default_user_preferences.listen
  property local : Bool = CONFIG.default_user_preferences.local
  property vr_mode : Bool = CONFIG.default_user_preferences.vr_mode
  property show_nick : Bool = CONFIG.default_user_preferences.show_nick

  @[JSON::Field(converter: Preferences::ProcessString)]
  property locale : String = CONFIG.default_user_preferences.locale

  @[JSON::Field(converter: Preferences::ClampInt)]
  property max_results : Int32 = CONFIG.default_user_preferences.max_results
  property notifications_only : Bool = CONFIG.default_user_preferences.notifications_only

  @[JSON::Field(converter: Preferences::ProcessString)]
  property player_style : String = CONFIG.default_user_preferences.player_style

  @[JSON::Field(converter: Preferences::ProcessString)]
  property quality : String = CONFIG.default_user_preferences.quality
  @[JSON::Field(converter: Preferences::ProcessString)]
  property quality_dash : String = CONFIG.default_user_preferences.quality_dash
  property default_home : String? = CONFIG.default_user_preferences.default_home
  property feed_menu : Array(String) = CONFIG.default_user_preferences.feed_menu
  property related_videos : Bool = CONFIG.default_user_preferences.related_videos

  @[JSON::Field(converter: Preferences::ProcessString)]
  property sort : String = CONFIG.default_user_preferences.sort
  property speed : Float32 = CONFIG.default_user_preferences.speed
  property thin_mode : Bool = CONFIG.default_user_preferences.thin_mode
  property unseen_only : Bool = CONFIG.default_user_preferences.unseen_only
  property video_loop : Bool = CONFIG.default_user_preferences.video_loop
  property extend_desc : Bool = CONFIG.default_user_preferences.extend_desc
  property volume : Int32 = CONFIG.default_user_preferences.volume

  module BoolToString
    def self.to_json(value : String, json : JSON::Builder)
      json.string value
    end

    def self.from_json(value : JSON::PullParser) : String
      begin
        result = value.read_string

        if result.empty?
          CONFIG.default_user_preferences.dark_mode
        else
          result
        end
      rescue ex
        if value.read_bool
          "dark"
        else
          "light"
        end
      end
    end

    def self.to_yaml(value : String, yaml : YAML::Nodes::Builder)
      yaml.scalar value
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : String
      unless node.is_a?(YAML::Nodes::Scalar)
        node.raise "Expected scalar, not #{node.class}"
      end

      case node.value
      when "true"
        "dark"
      when "false"
        "light"
      when ""
        CONFIG.default_user_preferences.dark_mode
      else
        node.value
      end
    end
  end

  module ClampInt
    def self.to_json(value : Int32, json : JSON::Builder)
      json.number value
    end

    def self.from_json(value : JSON::PullParser) : Int32
      value.read_int.clamp(0, MAX_ITEMS_PER_PAGE).to_i32
    end

    def self.to_yaml(value : Int32, yaml : YAML::Nodes::Builder)
      yaml.scalar value
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Int32
      node.value.clamp(0, MAX_ITEMS_PER_PAGE)
    end
  end

  module FamilyConverter
    def self.to_yaml(value : Socket::Family, yaml : YAML::Nodes::Builder)
      case value
      when Socket::Family::UNSPEC
        yaml.scalar nil
      when Socket::Family::INET
        yaml.scalar "ipv4"
      when Socket::Family::INET6
        yaml.scalar "ipv6"
      when Socket::Family::UNIX
        raise "Invalid socket family #{value}"
      end
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Socket::Family
      if node.is_a?(YAML::Nodes::Scalar)
        case node.value.downcase
        when "ipv4"
          Socket::Family::INET
        when "ipv6"
          Socket::Family::INET6
        else
          Socket::Family::UNSPEC
        end
      else
        node.raise "Expected scalar, not #{node.class}"
      end
    end
  end

  module URIConverter
    def self.to_yaml(value : URI, yaml : YAML::Nodes::Builder)
      yaml.scalar value.normalize!
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : URI
      if node.is_a?(YAML::Nodes::Scalar)
        URI.parse node.value
      else
        node.raise "Expected scalar, not #{node.class}"
      end
    end
  end

  module ProcessString
    def self.to_json(value : String, json : JSON::Builder)
      json.string value
    end

    def self.from_json(value : JSON::PullParser) : String
      HTML.escape(value.read_string[0, 100])
    end

    def self.to_yaml(value : String, yaml : YAML::Nodes::Builder)
      yaml.scalar value
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : String
      HTML.escape(node.value[0, 100])
    end
  end

  module StringToArray
    def self.to_json(value : Array(String), json : JSON::Builder)
      json.array do
        value.each do |element|
          json.string element
        end
      end
    end

    def self.from_json(value : JSON::PullParser) : Array(String)
      begin
        result = [] of String
        value.read_array do
          result << HTML.escape(value.read_string[0, 100])
        end
      rescue ex
        result = [HTML.escape(value.read_string[0, 100]), ""]
      end

      result
    end

    def self.to_yaml(value : Array(String), yaml : YAML::Nodes::Builder)
      yaml.sequence do
        value.each do |element|
          yaml.scalar element
        end
      end
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Array(String)
      begin
        unless node.is_a?(YAML::Nodes::Sequence)
          node.raise "Expected sequence, not #{node.class}"
        end

        result = [] of String
        node.nodes.each do |item|
          unless item.is_a?(YAML::Nodes::Scalar)
            node.raise "Expected scalar, not #{item.class}"
          end

          result << HTML.escape(item.value[0, 100])
        end
      rescue ex
        if node.is_a?(YAML::Nodes::Scalar)
          result = [HTML.escape(node.value[0, 100]), ""]
        else
          result = ["", ""]
        end
      end

      result
    end
  end

  module StringToCookies
    def self.to_yaml(value : HTTP::Cookies, yaml : YAML::Nodes::Builder)
      (value.map { |c| "#{c.name}=#{c.value}" }).join("; ").to_yaml(yaml)
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : HTTP::Cookies
      unless node.is_a?(YAML::Nodes::Scalar)
        node.raise "Expected scalar, not #{node.class}"
      end

      cookies = HTTP::Cookies.new
      node.value.split(";").each do |cookie|
        next if cookie.strip.empty?
        name, value = cookie.split("=", 2)
        cookies << HTTP::Cookie.new(name.strip, value.strip)
      end

      cookies
    end
  end
end

struct ConfigPreferences
  include YAML::Serializable

  property annotations : Bool = false
  property annotations_subscribed : Bool = false
  property autoplay : Bool = false
  property captions : Array(String) = ["", "", ""]
  property comments : Array(String) = ["youtube", ""]
  property continue : Bool = false
  property continue_autoplay : Bool = true
  property dark_mode : String = ""
  property latest_only : Bool = false
  property listen : Bool = false
  property local : Bool = false
  property locale : String = "en-US"
  property max_results : Int32 = 40
  property notifications_only : Bool = false
  property player_style : String = "invidious"
  property quality : String = "hd720"
  property quality_dash : String = "auto"
  property default_home : String? = "Popular"
  property feed_menu : Array(String) = ["Popular", "Trending", "Subscriptions", "Playlists"]
  property automatic_instance_redirect : Bool = false
  property related_videos : Bool = true
  property sort : String = "published"
  property speed : Float32 = 1.0_f32
  property thin_mode : Bool = false
  property unseen_only : Bool = false
  property video_loop : Bool = false
  property extend_desc : Bool = false
  property volume : Int32 = 100
  property vr_mode : Bool = true
  property show_nick : Bool = true

  def to_tuple
    {% begin %}
      {
        {{*@type.instance_vars.map { |var| "#{var.name}: #{var.name}".id }}}
      }
    {% end %}
  end
end

struct VideoPreferences
  include JSON::Serializable

  property annotations : Bool
  property autoplay : Bool
  property comments : Array(String)
  property continue : Bool
  property continue_autoplay : Bool
  property controls : Bool
  property listen : Bool
  property local : Bool
  property preferred_captions : Array(String)
  property player_style : String
  property quality : String
  property quality_dash : String
  property raw : Bool
  property region : String?
  property related_videos : Bool
  property speed : Float32 | Float64
  property video_end : Float64 | Int32
  property video_loop : Bool
  property extend_desc : Bool
  property video_start : Float64 | Int32
  property volume : Int32
  property vr_mode : Bool
end

def process_video_params(query, preferences)
  annotations = query["iv_load_policy"]?.try &.to_i?
  autoplay = query["autoplay"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  comments = query["comments"]?.try &.split(",").map { |a| a.downcase }
  continue = query["continue"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  continue_autoplay = query["continue_autoplay"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  listen = query["listen"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  local = query["local"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  player_style = query["player_style"]?
  preferred_captions = query["subtitles"]?.try &.split(",").map { |a| a.downcase }
  quality = query["quality"]?
  quality_dash = query["quality_dash"]?
  region = query["region"]?
  related_videos = query["related_videos"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  speed = query["speed"]?.try &.rchop("x").to_f?
  video_loop = query["loop"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  extend_desc = query["extend_desc"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  volume = query["volume"]?.try &.to_i?
  vr_mode = query["vr_mode"]?.try { |q| (q == "true" || q == "1").to_unsafe }

  if preferences
    # region ||= preferences.region
    annotations ||= preferences.annotations.to_unsafe
    autoplay ||= preferences.autoplay.to_unsafe
    comments ||= preferences.comments
    continue ||= preferences.continue.to_unsafe
    continue_autoplay ||= preferences.continue_autoplay.to_unsafe
    listen ||= preferences.listen.to_unsafe
    local ||= preferences.local.to_unsafe
    player_style ||= preferences.player_style
    preferred_captions ||= preferences.captions
    quality ||= preferences.quality
    quality_dash ||= preferences.quality_dash
    related_videos ||= preferences.related_videos.to_unsafe
    speed ||= preferences.speed
    video_loop ||= preferences.video_loop.to_unsafe
    extend_desc ||= preferences.extend_desc.to_unsafe
    volume ||= preferences.volume
    vr_mode ||= preferences.vr_mode.to_unsafe
  end

  annotations ||= CONFIG.default_user_preferences.annotations.to_unsafe
  autoplay ||= CONFIG.default_user_preferences.autoplay.to_unsafe
  comments ||= CONFIG.default_user_preferences.comments
  continue ||= CONFIG.default_user_preferences.continue.to_unsafe
  continue_autoplay ||= CONFIG.default_user_preferences.continue_autoplay.to_unsafe
  listen ||= CONFIG.default_user_preferences.listen.to_unsafe
  local ||= CONFIG.default_user_preferences.local.to_unsafe
  player_style ||= CONFIG.default_user_preferences.player_style
  preferred_captions ||= CONFIG.default_user_preferences.captions
  quality ||= CONFIG.default_user_preferences.quality
  quality_dash ||= CONFIG.default_user_preferences.quality_dash
  related_videos ||= CONFIG.default_user_preferences.related_videos.to_unsafe
  speed ||= CONFIG.default_user_preferences.speed
  video_loop ||= CONFIG.default_user_preferences.video_loop.to_unsafe
  extend_desc ||= CONFIG.default_user_preferences.extend_desc.to_unsafe
  volume ||= CONFIG.default_user_preferences.volume
  vr_mode ||= CONFIG.default_user_preferences.vr_mode.to_unsafe

  annotations = annotations == 1
  autoplay = autoplay == 1
  continue = continue == 1
  continue_autoplay = continue_autoplay == 1
  listen = listen == 1
  local = local == 1
  related_videos = related_videos == 1
  video_loop = video_loop == 1
  extend_desc = extend_desc == 1
  vr_mode = vr_mode == 1

  if CONFIG.disabled?("dash") && quality == "dash"
    quality = "high"
  end

  if CONFIG.disabled?("local") && local
    local = false
  end

  if start = query["t"]? || query["time_continue"]? || query["start"]?
    video_start = decode_time(start)
  end
  video_start ||= 0

  if query["end"]?
    video_end = decode_time(query["end"])
  end
  video_end ||= -1

  raw = query["raw"]?.try &.to_i?
  raw ||= 0
  raw = raw == 1

  controls = query["controls"]?.try &.to_i?
  controls ||= 1
  controls = controls >= 1

  params = VideoPreferences.new({
    annotations:        annotations,
    autoplay:           autoplay,
    comments:           comments,
    continue:           continue,
    continue_autoplay:  continue_autoplay,
    controls:           controls,
    listen:             listen,
    local:              local,
    player_style:       player_style,
    preferred_captions: preferred_captions,
    quality:            quality,
    quality_dash:       quality_dash,
    raw:                raw,
    region:             region,
    related_videos:     related_videos,
    speed:              speed,
    video_end:          video_end,
    video_loop:         video_loop,
    extend_desc:        extend_desc,
    video_start:        video_start,
    volume:             volume,
    vr_mode:            vr_mode,
  })

  return params
end
