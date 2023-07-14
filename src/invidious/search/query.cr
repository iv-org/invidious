module Invidious::Search
  class Query
    enum Type
      # Types related to YouTube
      Regular # Youtube search page
      Channel # Youtube channel search box

      # Types specific to Invidious
      Subscriptions # Search user subscriptions
      Playlist      # "Add playlist item" search
    end

    getter type : Type = Type::Regular

    @raw_query : String
    @query : String = ""

    property filters : Filters = Filters.new
    property page : Int32
    property region : String?
    property channel : String = ""

    # Return true if @raw_query is either `nil` or empty
    private def empty_raw_query?
      return @raw_query.empty?
    end

    # Same as `empty_raw_query?`, but named for external use
    def empty?
      return self.empty_raw_query?
    end

    # Getter for the query string.
    # It is named `text` to reduce confusion (`search_query.text` makes more
    # sense than `search_query.query`)
    def text
      return @query
    end

    # Initialize a new search query.
    # Parameters are used to get the query string, the page number
    # and the search filters (if any). Type tells this function
    # where it is being called from (See `Type` above).
    def initialize(
      params : HTTP::Params,
      @type : Type = Type::Regular,
      @region : String? = nil
    )
      # Get the raw search query string (common to all search types). In
      # Regular search mode, also look for the `search_query` URL parameter
      if @type.regular?
        @raw_query = params["q"]? || params["search_query"]? || ""
      else
        @raw_query = params["q"]? || ""
      end

      # Get the page number (also common to all search types)
      @page = params["page"]?.try &.to_i? || 1

      # Stop here if raw query is empty
      # NOTE: maybe raise in the future?
      return if self.empty_raw_query?

      # Specific handling
      case @type
      when .channel?
        # In "channel search" mode, filters are ignored, but we still parse
        # the query prevent transmission of legacy filters to youtube.
        #
        _, _, @query, _ = Filters.from_legacy_filters(@raw_query)
        #
      when .playlist?
        # In "add playlist item" mode, filters are parsed from the query
        # string itself (legacy), and the channel is ignored.
        #
        @filters, _, @query, _ = Filters.from_legacy_filters(@raw_query)
        #
      when .subscriptions?, .regular?
        if params["sp"]?
          # Parse the `sp` URL parameter (youtube compatibility)
          @filters = Filters.from_yt_params(params)
          @query = @raw_query || ""
        else
          # Parse invidious URL parameters (sort, date, etc...)
          @filters = Filters.from_iv_params(params)
          @channel = params["channel"]? || ""

          if @filters.default? && @raw_query.includes?(':')
            # Parse legacy filters from query
            @filters, @channel, @query, subs = Filters.from_legacy_filters(@raw_query)
          else
            @query = @raw_query || ""
          end

          if !@channel.empty?
            # Switch to channel search mode (filters will be ignored)
            @type = Type::Channel
          elsif subs
            # Switch to subscriptions search mode
            @type = Type::Subscriptions
          end
        end
      end
    end

    # Run the search query using the corresponding search processor.
    # Returns either the results or an empty array of `SearchItem`.
    def process(user : Invidious::User? = nil) : Array(SearchItem) | Array(ChannelVideo)
      items = [] of SearchItem

      # Don't bother going further if search query is empty
      return items if self.empty_raw_query?

      case @type
      when .regular?, .playlist?
        items = Processors.regular(self)
        #
      when .channel?
        items = Processors.channel(self)
        #
      when .subscriptions?
        if user
          items = Processors.subscriptions(self, user.as(Invidious::User))
        end
      end

      return items
    end

    # Return the HTTP::Params corresponding to this Query (invidious format)
    def to_http_params : HTTP::Params
      params = @filters.to_iv_params

      params["q"] = @query
      params["channel"] = @channel if !@channel.empty?

      return params
    end
  end
end
