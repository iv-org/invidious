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
    end

    def default? : Bool
      return @date.none? && @type.all? && @duration.none? && \
         @features.none? && @sort.relevance?
    end

    # -------------------
    #  Invidious params
    # -------------------

    def self.parse_features(raw : Array(String)) : Features
      # Initialize return variable
      features = Features.new(0)

      raw.each do |ft|
        case ft.downcase
        when "live", "livestream"
          features = features | Features::Live
        when "4k"        then features = features | Features::FourK
        when "hd"        then features = features | Features::HD
        when "subtitles" then features = features | Features::Subtitles
        when "creative_commons", "commons", "cc"
          features = features | Features::CCommons
        when "360"       then features = features | Features::ThreeSixty
        when "vr180"     then features = features | Features::VR180
        when "3d"        then features = features | Features::ThreeD
        when "hdr"       then features = features | Features::HDR
        when "location"  then features = features | Features::Location
        when "purchased" then features = features | Features::Purchased
        end
      end

      return features
    end

    def self.format_features(features : Features) : String
      # Directly return an empty string if there are no features
      return "" if features.none?

      # Initialize return variable
      str = [] of String

      str << "live" if features.live?
      str << "4k" if features.four_k?
      str << "hd" if features.hd?
      str << "subtitles" if features.subtitles?
      str << "commons" if features.c_commons?
      str << "360" if features.three_sixty?
      str << "vr180" if features.vr180?
      str << "3d" if features.three_d?
      str << "hdr" if features.hdr?
      str << "location" if features.location?
      str << "purchased" if features.purchased?

      return str.join(',')
    end

    def self.from_legacy_filters(str : String) : {Filters, String, String, Bool}
      # Split search query on spaces
      members = str.split(' ')

      # Output variables
      channel = ""
      filters = Filters.new
      subscriptions = false

      # Array to hold the non-filter members
      query = [] of String

      # Parse!
      members.each do |substr|
        # Separator operators
        operators = substr.split(':')

        case operators[0]
        when "user", "channel"
          next if operators.size != 2
          channel = operators[1]
          #
        when "type", "content_type"
          next if operators.size != 2
          type = Type.parse?(operators[1])
          filters.type = type if !type.nil?
          #
        when "date"
          next if operators.size != 2
          date = Date.parse?(operators[1])
          filters.date = date if !date.nil?
          #
        when "duration"
          next if operators.size != 2
          duration = Duration.parse?(operators[1])
          filters.duration = duration if !duration.nil?
          #
        when "feature", "features"
          next if operators.size != 2
          features = parse_features(operators[1].split(','))
          filters.features = features if !features.nil?
          #
        when "sort"
          next if operators.size != 2
          sort = Sort.parse?(operators[1])
          filters.sort = sort if !sort.nil?
          #
        when "subscriptions"
          next if operators.size != 2
          subscriptions = {"true", "on", "yes", "1"}.any?(&.== operators[1])
          #
        else
          query << substr
        end
      end

      # Re-assemble query (without filters)
      cleaned_query = query.join(' ')

      return {filters, channel, cleaned_query, subscriptions}
    end

    def self.from_iv_params(params : HTTP::Params) : Filters
      # Temporary variables
      filters = Filters.new

      if type = params["type"]?
        filters.type = Type.parse?(type) || Type::All
        params.delete("type")
      end

      if date = params["date"]?
        filters.date = Date.parse?(date) || Date::None
        params.delete("date")
      end

      if duration = params["duration"]?
        filters.duration = Duration.parse?(duration) || Duration::None
        params.delete("duration")
      end

      features = params.fetch_all("features")
      if !features.empty?
        # Un-array input so it can be treated as a comma-separated list
        features = features[0].split(',') if features.size == 1

        filters.features = parse_features(features) || Features::None
        params.delete_all("features")
      end

      if sort = params["sort"]?
        filters.sort = Sort.parse?(sort) || Sort::Relevance
        params.delete("sort")
      end

      return filters
    end

    def to_iv_params : HTTP::Params
      # Temporary variables
      raw_params = {} of String => Array(String)

      raw_params["date"] = [@date.to_s.underscore] if !@date.none?
      raw_params["type"] = [@type.to_s.underscore] if !@type.all?
      raw_params["sort"] = [@sort.to_s.underscore] if !@sort.relevance?

      if !@duration.none?
        raw_params["duration"] = [@duration.to_s.underscore]
      end

      if !@features.none?
        raw_params["features"] = [Filters.format_features(@features)]
      end

      return HTTP::Params.new(raw_params)
    end

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

    # Function to parse the `sp` URL parameter from Youtube
    # search page. It's a base64-encoded protobuf object.
    def self.from_yt_params(params : HTTP::Params) : Filters
      # Initialize output variable
      filters = Filters.new

      # Get parameter, and check emptyness
      search_params = params["sp"]?

      if search_params.nil? || search_params.empty?
        return filters
      end

      # Decode protobuf object
      object = search_params
        .try { |i| URI.decode_www_form(i) }
        .try { |i| Base64.decode(i) }
        .try { |i| IO::Memory.new(i) }
        .try { |i| Protodec::Any.parse(i) }

      # Parse items from embedded object
      if embedded = object["2:0:embedded"]?
        # All the following fields (date, type, duration) are optional.
        if date = embedded["1:0:varint"]?
          filters.date = Date.from_value?(date.as_i) || Date::None
        end

        if type = embedded["2:0:varint"]?
          filters.type = Type.from_value?(type.as_i) || Type::All
        end

        if duration = embedded["3:0:varint"]?
          filters.duration = Duration.from_value?(duration.as_i) || Duration::None
        end

        # All features should have a value of "1" when enabled, and
        # the field should be omitted when the feature is no selected.
        features = 0
        features += (embedded["4:0:varint"]?.try &.as_i == 1_i64) ? Features::HD.value : 0
        features += (embedded["5:0:varint"]?.try &.as_i == 1_i64) ? Features::Subtitles.value : 0
        features += (embedded["6:0:varint"]?.try &.as_i == 1_i64) ? Features::CCommons.value : 0
        features += (embedded["7:0:varint"]?.try &.as_i == 1_i64) ? Features::ThreeD.value : 0
        features += (embedded["8:0:varint"]?.try &.as_i == 1_i64) ? Features::Live.value : 0
        features += (embedded["9:0:varint"]?.try &.as_i == 1_i64) ? Features::Purchased.value : 0
        features += (embedded["14:0:varint"]?.try &.as_i == 1_i64) ? Features::FourK.value : 0
        features += (embedded["15:0:varint"]?.try &.as_i == 1_i64) ? Features::ThreeSixty.value : 0
        features += (embedded["23:0:varint"]?.try &.as_i == 1_i64) ? Features::Location.value : 0
        features += (embedded["25:0:varint"]?.try &.as_i == 1_i64) ? Features::HDR.value : 0
        features += (embedded["26:0:varint"]?.try &.as_i == 1_i64) ? Features::VR180.value : 0

        filters.features = Features.from_value?(features) || Features::None
      end

      if sort = object["1:0:varint"]?
        filters.sort = Sort.from_value?(sort.as_i) || Sort::Relevance
      end

      # Remove URL parameter and return result
      params.delete("sp")
      return filters
    end
  end
end
