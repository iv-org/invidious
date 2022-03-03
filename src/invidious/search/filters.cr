require "protodec/utils"
require "http/params"

module Invidious::Search
  struct Filters
    # Values correspond to { "2:embedded": { "1:varint": <X> }}
    # except for "None" which is only used by us (= nothing selected)
    enum Date
      None  = 0
      Hour  = 1
      Today = 2
      Week  = 3
      Month = 4
      Year  = 5
    end

    # Values correspond to { "2:embedded": { "2:varint": <X> }}
    # except for "All" which is only used by us (= nothing selected)
    enum Type
      All      = 0
      Video    = 1
      Channel  = 2
      Playlist = 3
      Movie    = 4

      # Has it been removed?
      # (Not available on youtube's UI)
      Show = 5
    end

    # Values correspond to { "2:embedded": { "3:varint": <X> }}
    # except for "None" which is only used by us (= nothing selected)
    enum Duration
      None   = 0
      Short  = 1 # "Under 4 minutes"
      Long   = 2 # "Over 20 minutes"
      Medium = 3 # "4 - 20 minutes"
    end

    # Note: flag enums automatically generate
    # "none" and "all" members
    @[Flags]
    enum Features
      Live
      FourK # "4K"
      HD
      Subtitles  # "Subtitles/CC"
      CCommons   # "Creative Commons"
      ThreeSixty # "360°"
      VR180
      ThreeD # "3D"
      HDR
      Location
      Purchased
    end

    # Values correspond to { "1:varint": <X> }
    enum Sort
      Relevance = 0
      Rating    = 1
      Date      = 2
      Views     = 3
    end

    # Parameters are sorted as on Youtube
    property date : Date
    property type : Type
    property duration : Duration
    property features : Features
    property sort : Sort

    def initialize(
      *, # All parameters must be named
      @date : Date = Date::None,
      @type : Type = Type::All,
      @duration : Duration = Duration::None,
      @features : Features = Features::None,
      @sort : Sort = Sort::Relevance
    )
    # -------------------
    #  Youtube params
    # -------------------

    # Produce the youtube search parameters for the
    # innertube API (base64-encoded protobuf object).
    def to_yt_params(page : Int = 1) : String
      # Initialize the embedded protobuf object
      embedded = {} of String => Int64

      # Add these field only if associated parameter is selected
      embedded["1:varint"] = @date.to_i64 if !@date.none?
      embedded["2:varint"] = @type.to_i64 if !@type.all?
      embedded["3:varint"] = @duration.to_i64 if !@duration.none?

      if !@features.none?
        # All features have a value of "1" when enabled, and
        # the field is omitted when the feature is no selected.
        embedded["4:varint"] = 1_i64 if @features.includes?(Features::HD)
        embedded["5:varint"] = 1_i64 if @features.includes?(Features::Subtitles)
        embedded["6:varint"] = 1_i64 if @features.includes?(Features::CCommons)
        embedded["7:varint"] = 1_i64 if @features.includes?(Features::ThreeD)
        embedded["8:varint"] = 1_i64 if @features.includes?(Features::Live)
        embedded["9:varint"] = 1_i64 if @features.includes?(Features::Purchased)
        embedded["14:varint"] = 1_i64 if @features.includes?(Features::FourK)
        embedded["15:varint"] = 1_i64 if @features.includes?(Features::ThreeSixty)
        embedded["23:varint"] = 1_i64 if @features.includes?(Features::Location)
        embedded["25:varint"] = 1_i64 if @features.includes?(Features::HDR)
        embedded["26:varint"] = 1_i64 if @features.includes?(Features::VR180)
      end

      # Initialize an empty protobuf object
      object = {} of String => (Int64 | String | Hash(String, Int64))

      # As usual, everything can be omitted if it has no value
      object["2:embedded"] = embedded if !embedded.empty?

      # Default sort is "relevance", so when this option is selected,
      # the associated field can be omitted.
      if !@sort.relevance?
        object["1:varint"] = @sort.to_i64
      end

      # Add page number (if provided)
      if page > 1
        object["9:varint"] = ((page - 1) * 20).to_i64
      end

      # If the object is empty, return an empty string,
      # otherwise encode to protobuf then to base64
      return "" if object.empty?

      return object
        .try { |i| Protodec::Any.cast_json(i) }
        .try { |i| Protodec::Any.from_json(i) }
        .try { |i| Base64.urlsafe_encode(i) }
        .try { |i| URI.encode_www_form(i) }
    end
  end
end
