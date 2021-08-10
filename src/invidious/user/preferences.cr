#
# This file contains the user preferences data structures and
# all the associated validation/parsing routines.
#

require "json"
require "yaml"
require "html"

#
# Enumerates types and constants
#

module Settings
  ALLOWED_SPEED_VALUES = {
    2.00_f32, # Double speed
    1.75_f32,
    1.50_f32,
    1.25_f32,
    1.00_f32, # Normal
    0.75_f32,
    0.50_f32, # Half speed
    0.25_f32,
  }

  enum Themes
    Auto # I.e use the system's settings with media queries
    Light
    Dark
  end

  enum PlayerStyles
    Invidious
    Youtube
  end

  # General
  enum HomePages
    Search
    Popular
    Trending
  end

  # Authenticated
  enum UserHomePages
    Subscriptions
    Playlists
  end

  alias AnyHomePages = HomePages | UserHomePages

  enum SortOptions
    Alphabetically
    Alphabetically_Reverse
    Channel_Name
    Channel_Name_Reverse
    Publication_Date
    Publication_Date_Reverse
  end

  # Unused for now, reuires merging
  enum VideoQualities
    # Normal
    HD720
    Medium
    Small
    # Dash
    DASH_Auto
    DASH_Best
    DASH_4320p
    DASH_2160p
    DASH_1440p
    DASH_1080p
    DASH_720p
    DASH_480p
    DASH_360p
    DASH_240p
    DASH_144p
    DASH_Worst
  end
end

#
# Data structure that stores a user's preferences.
#

class Preferences
  include JSON::Serializable
  include YAML::Serializable

  property annotations : Bool = false
  property annotations_subscribed : Bool = false

  property autoplay : Bool = false
  property automatic_instance_redirect : Bool = false

  @[JSON::Field(converter: Preferences::StringToArray)]
  @[YAML::Field(converter: Preferences::StringToArray)]
  property captions : Array(String) = ["", "", ""]

  @[JSON::Field(converter: Preferences::StringToArray)]
  @[YAML::Field(converter: Preferences::StringToArray)]
  property comments : Array(String) = ["youtube", ""]

  property continue : Bool = false
  property continue_autoplay : Bool = true

  @[JSON::Field(converter: Settings::Converters::Generic(Settings::Themes))]
  @[YAML::Field(converter: Settings::Converters::Generic(Settings::Themes))]
  property dark_mode : Settings::Themes = Settings::Themes::Dark

  property latest_only : Bool = false

  property listen : Bool = false
  property local : Bool = false
  property vr_mode : Bool = true
  property show_nick : Bool = true

  @[JSON::Field(converter: Preferences::ProcessString)]
  property locale : String = "en-US"

  @[JSON::Field(converter: Preferences::ClampInt)]
  property max_results : Int32 = 40
  property notifications_only : Bool = false

  @[JSON::Field(converter: Settings::Converters::Generic(Settings::PlayerStyles))]
  @[YAML::Field(converter: Settings::Converters::Generic(Settings::PlayerStyles))]
  property player_style : Settings::PlayerStyles = Settings::PlayerStyles::Invidious

  @[JSON::Field(converter: Preferences::ProcessString)]
  property quality : String = "hd720"
  @[JSON::Field(converter: Preferences::ProcessString)]
  property quality_dash : String = "auto"

  @[JSON::Field(converter: Settings::Converters::Generic(Settings::AnyHomePages))]
  @[YAML::Field(converter: Settings::Converters::Generic(Settings::AnyHomePages))]
  property default_home : Settings::AnyHomePages = Settings::HomePages::Popular

  @[JSON::Field(converter: Settings::Converters::Generic(Array(Settings::AnyHomePages)))]
  @[YAML::Field(converter: Settings::Converters::Generic(Array(Settings::AnyHomePages)))]
  property feed_menu : Array(Settings::AnyHomePages) = [
    Settings::HomePages::Popular,
    Settings::HomePages::Trending,
    Settings::UserHomePages::Subscriptions,
    Settings::UserHomePages::Playlists,
  ]

  property related_videos : Bool = true

  @[JSON::Field(converter: Settings::Converters::Generic(Settings::SortOptions))]
  @[YAML::Field(converter: Settings::Converters::Generic(Settings::SortOptions))]
  property sort : Settings::SortOptions = Settings::SortOptions::Publication_Date

  property speed : Float32 = 1.0_f32

  property thin_mode : Bool = false
  property unseen_only : Bool = false
  property video_loop : Bool = false
  property extend_desc : Bool = false

  property volume : Int32 = 100

  def initialize
  end

  # Duplicate (make a perfect copy of) the current object
  def dup
    other = Preferences.new

    {% for ivar in @type.instance_vars %}
      other.{{ ivar.id }} = {{ ivar.id }}
    {% end %}

    return other
  end

  # :nodoc:
  def text_dump(include_defaults = false)
    {% for ivar in @type.instance_vars %}
      name    = {{ ivar.id.stringify }}
      value   = {{ ivar.id }}
      default = {{ ivar.default_value }}

      puts "#{name} = #{value}" if (include_defaults || value != default)
    {% end %}
  end

  # :nodoc:
  def text_dump(other : Preferences)
    # Macro that dumps, as text, all the contents of that struct
    {% for ivar in @type.instance_vars %}
      name = {{ ivar.id.stringify }}
      val1 = self.{{ ivar.id }}
      val2 = other.{{ ivar.id }}

      puts "#{name} = #{val1}" if val1 != val2
    {% end %}
  end

  def toggle_theme
    old = @dark_mode
    @dark_mode = (old.dark?) ? Settings::Themes::Light : Settings::Themes::Dark
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

  def to_tuple
    {% begin %}
      {
        {{*@type.instance_vars.map { |var| "#{var.name}: #{var.name}".id }}}
      }
    {% end %}
  end
end # class Data

#
# Datatype converters (also act as data validators)
#

module Settings::Converters
  #
  # Generic enum conversion
  #
  module Generic(T)
    extend self

    # From/To JSON

    def to_json(value : T, json : JSON::Builder)
      value.to_json json
    end

    def from_json(value : JSON::PullParser) : T?
      begin
        T.new value
      rescue e : JSON::ParseException
        # Be silent on invalid data and return nil
        # This will fallback to the default value
      end
    end

    # From/To YAML

    def to_yaml(value : T, yaml : YAML::Nodes::Builder)
      value.to_yaml yaml
    end

    def from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : T?
      begin
        T.new ctx, node
      rescue e : YAML::ParseException
        # Be silent on invalid data and return nil
        # This will fallback to the default value
      end
    end
  end # module Generic

  #
  # Themes enum conversion
  #
  module Theme
    extend self

    # From String (.to_s is native of Enum type)

    def from_s(input : String?) : Themes?
      return if !input

      case input.downcase
      when "auto" ; Themes::Auto
      when "light"; Themes::Light
      when "dark" ; Themes::Dark
        # Compatibility with old 'dark_mode' values
      when "false"; Themes::Light
      when "true" ; Themes::Dark
      else
        # Nothing, use default from initialization
      end
    end

    # From/To JSON

    def to_json(value : Themes, json : JSON::Builder)
      json.string value.to_s
    end

    def from_json(value : JSON::PullParser) : Themes?
      return self.from_s(value.read_string)
    end

    # From/To YAML

    def to_yaml(value : Themes, yaml : YAML::Nodes::Builder)
      yaml.scalar value.to_s
    end

    def from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Themes?
      unless node.is_a?(YAML::Nodes::Scalar)
        node.raise "Expected scalar, not #{node.class}"
      end

      return self.from_s(node.value)
    end
  end # module theme

end # module Settings::Converters

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
    player_style ||= preferences.player_style.to_s
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
  player_style ||= CONFIG.default_user_preferences.player_style.to_s
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
