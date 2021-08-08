module YouTubeStructs
  # Struct to represent channel heading information.
  #
  # As of master this is mostly taken from the about tab.
  #
  # TODO: Refactor into into ChannelInformation
  struct AboutChannel
    include DB::Serializable

    property ucid : String
    property author : String
    property auto_generated : Bool
    property author_url : String
    property author_thumbnail : String
    property banner : String?
    property description_html : String
    property total_views : Int64
    property sub_count : Int32
    property joined : Time
    property is_family_friendly : Bool
    property allowed_regions : Array(String)
    property related_channels : Array(AboutRelatedChannel)
    property tabs : Array(String)
  end

  # TODO this should be removed. YouTube has removed related channels.
  struct AboutRelatedChannel
    include DB::Serializable

    property ucid : String
    property author : String
    property author_url : String
    property author_thumbnail : String
  end
end
