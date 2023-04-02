struct Preferences
  include JSON::Serializable

  property annotations : Bool = CONFIG.default_user_preferences.annotations
  property annotations_subscribed : Bool = CONFIG.default_user_preferences.annotations_subscribed
  property autoplay : Bool = CONFIG.default_user_preferences.autoplay
  property automatic_instance_redirect : Bool = CONFIG.default_user_preferences.automatic_instance_redirect

  @[JSON::Field(converter: Preferences::StringToArray)]
  property captions : Array(String) = CONFIG.default_user_preferences.captions

  @[JSON::Field(converter: Preferences::StringToArray)]
  property comments : Array(String) = CONFIG.default_user_preferences.comments
  property continue : Bool = CONFIG.default_user_preferences.continue
  property continue_autoplay : Bool = CONFIG.default_user_preferences.continue_autoplay

  @[JSON::Field(converter: Preferences::BoolToString)]
  property dark_mode : String = CONFIG.default_user_preferences.dark_mode
  property latest_only : Bool = CONFIG.default_user_preferences.latest_only
  property listen : Bool = CONFIG.default_user_preferences.listen
  property local : Bool = CONFIG.default_user_preferences.local
  property watch_history : Bool = CONFIG.default_user_preferences.watch_history
  property vr_mode : Bool = CONFIG.default_user_preferences.vr_mode
  property show_nick : Bool = CONFIG.default_user_preferences.show_nick

  @[JSON::Field(converter: Preferences::ProcessString)]
  property locale : String = CONFIG.default_user_preferences.locale
  property region : String? = CONFIG.default_user_preferences.region

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
  property save_player_pos : Bool = CONFIG.default_user_preferences.save_player_pos

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
  end

  module ClampInt
    def self.to_json(value : Int32, json : JSON::Builder)
      json.number value
    end

    def self.from_json(value : JSON::PullParser) : Int32
      value.read_int.clamp(0, MAX_ITEMS_PER_PAGE).to_i32
    end
  end

  module ProcessString
    def self.to_json(value : String, json : JSON::Builder)
      json.string value
    end

    def self.from_json(value : JSON::PullParser) : String
      HTML.escape(value.read_string[0, 100])
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
  end
end
