module InvidiousStructs
  # Struct containing all values for video preferences
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
end
