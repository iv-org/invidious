module Invidious::Search
  module Processors
    extend self

    # Regular search (`/search` endpoint)
    def regular(query : Query) : Array(SearchItem)
      search_params = query.filters.to_yt_params(page: query.page)

      client_config = YoutubeAPI::ClientConfig.new(region: query.region)
      initial_data = YoutubeAPI.search(query.text, search_params, client_config: client_config)

      return extract_items(initial_data)
    end

    # Search a youtube channel
    # TODO: clean code, and rely more on YoutubeAPI
    def channel(query : Query) : Array(SearchItem)
      response = YT_POOL.client &.get("/channel/#{query.channel}")

      if response.status_code == 404
        response = YT_POOL.client &.get("/user/#{query.channel}")
        response = YT_POOL.client &.get("/c/#{query.channel}") if response.status_code == 404
        initial_data = extract_initial_data(response.body)
        ucid = initial_data.dig?("header", "c4TabbedHeaderRenderer", "channelId").try(&.as_s?)
        raise ChannelSearchException.new(query.channel) if !ucid
      else
        ucid = query.channel
      end

      continuation = produce_channel_search_continuation(ucid, query.text, query.page)
      response_json = YoutubeAPI.browse(continuation)

      continuation_items = response_json["onResponseReceivedActions"]?
        .try &.[0]["appendContinuationItemsAction"]["continuationItems"]

      return [] of SearchItem if !continuation_items

      items = [] of SearchItem
      continuation_items.as_a.select(&.as_h.has_key?("itemSectionRenderer")).each do |item|
        extract_item(item["itemSectionRenderer"]["contents"].as_a[0]).try { |t| items << t }
      end

      return items
    end

    # Search inside of user subscriptions
    def subscriptions(query : Query, user : Invidious::User) : Array(ChannelVideo)
      view_name = "subscriptions_#{sha256(user.email)}"

      return PG_DB.query_all("
        SELECT id,title,published,updated,ucid,author,length_seconds
        FROM (
          SELECT *,
          to_tsvector(#{view_name}.title) ||
          to_tsvector(#{view_name}.author)
          as document
          FROM #{view_name}
        ) v_search WHERE v_search.document @@ plainto_tsquery($1) LIMIT 20 OFFSET $2;",
        query.text, (query.page - 1) * 20,
        as: ChannelVideo
      )
    end
  end
end
