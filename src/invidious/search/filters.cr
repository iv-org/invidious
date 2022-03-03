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
  end
end
