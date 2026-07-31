module Invidious::LiveChat
  extend self

  alias CacheKey = Tuple(String, String, String, String)

  CACHE_LIMIT = 256
  FETCH_LOCKS = Array(Mutex).new(16) { Mutex.new }

  record CacheEntry, body : String, expires_at : Time::Instant

  @@cache = {} of CacheKey => CacheEntry
  @@cache_mutex = Mutex.new

  struct Action
    include JSON::Serializable

    getter action : String

    @[JSON::Field(emit_null: false)]
    getter id : String?

    @[JSON::Field(emit_null: false)]
    getter kind : String?

    @[JSON::Field(emit_null: false)]
    getter author : String?

    @[JSON::Field(emit_null: false)]
    getter message : String?

    @[JSON::Field(emit_null: false)]
    getter badges : Array(String)?

    def initialize(
      @action : String,
      @id : String? = nil,
      @kind : String? = nil,
      @author : String? = nil,
      @message : String? = nil,
      @badges : Array(String)? = nil,
    )
    end
  end

  struct Response
    include JSON::Serializable

    @[JSON::Field(emit_null: false)]
    getter continuation : String?

    @[JSON::Field(key: "timeoutMs")]
    getter timeout_ms : Int32

    getter actions : Array(Action)

    def initialize(
      @continuation : String?,
      @timeout_ms : Int32,
      @actions : Array(Action),
    )
    end
  end

  def fetch(video_id : String, continuation : String?, region : String?, mode : String) : String
    cache_key = {video_id, continuation || "", region || "", mode}

    fetch_lock(cache_key).synchronize do
      if cached = cached_response(cache_key)
        return cached
      end

      client_config = YoutubeAPI::ClientConfig.new(region: region)
      response = if continuation
                   YoutubeAPI.live_chat(continuation, client_config: client_config)
                 else
                   fetch_initial_response(video_id, mode, client_config)
                 end

      response = parse_response(response)
      body = response.to_json
      cache_response(cache_key, body, response.timeout_ms)
      return body
    end
  end

  private def fetch_initial_response(
    video_id : String,
    mode : String,
    client_config : YoutubeAPI::ClientConfig,
  ) : Hash(String, JSON::Any)
    next_response = YoutubeAPI.next({"videoId" => video_id}, client_config: client_config)
    initial_continuation = extract_initial_continuation(next_response) ||
                           raise NotFoundException.new("Live chat is unavailable.")
    initial_response = YoutubeAPI.live_chat(initial_continuation, client_config: client_config)
    return initial_response unless mode == "live"

    live_continuation = extract_live_continuation(initial_response) ||
                        raise NotFoundException.new("Live chat is unavailable.")
    return YoutubeAPI.live_chat(live_continuation, client_config: client_config)
  end

  def extract_initial_continuation(response : Hash(String, JSON::Any)) : String?
    live_chat = response
      .dig?("contents", "twoColumnWatchNextResults", "conversationBar", "liveChatRenderer")
    return nil unless live_chat

    continuations = live_chat["continuations"]?.try &.as_a?
    return nil unless continuations

    continuations.each do |entry|
      continuation = continuation_from(entry["reloadContinuationData"]?)
      return continuation if continuation
    end

    return nil
  end

  def extract_live_continuation(response : Hash(String, JSON::Any)) : String?
    items = response
      .dig?(
        "continuationContents",
        "liveChatContinuation",
        "header",
        "liveChatHeaderRenderer",
        "viewSelector",
        "sortFilterSubMenuRenderer",
        "subMenuItems",
      )
      .try &.as_a?

    live_item = items.try &.find do |item|
      item["title"]?.try(&.as_s?) == "Live chat"
    end

    return continuation_from(live_item.try &.dig?("continuation", "reloadContinuationData"))
  end

  def parse_response(response : Hash(String, JSON::Any)) : Response
    live_chat = response.dig?("continuationContents", "liveChatContinuation")
    return Response.new(nil, 10_000, [] of Action) unless live_chat

    actions = [] of Action

    live_chat["actions"]?.try(&.as_a?).try &.each do |action|
      if added = parse_add_action(action)
        actions << added
      elsif target_id = action.dig?("removeChatItemAction", "targetItemId").try &.as_s?
        actions << Action.new("remove", id: target_id)
      end
    end

    continuation, timeout_ms = extract_polling_data(live_chat["continuations"]?.try(&.as_a?))
    return Response.new(continuation, timeout_ms, actions)
  end

  private def fetch_lock(cache_key : CacheKey) : Mutex
    index = (cache_key.hash % FETCH_LOCKS.size).to_i
    return FETCH_LOCKS[index]
  end

  private def cached_response(cache_key : CacheKey) : String?
    now = Time.instant

    @@cache_mutex.synchronize do
      entry = @@cache[cache_key]?
      return nil unless entry

      if entry.expires_at <= now
        @@cache.delete(cache_key)
        return nil
      end

      return entry.body
    end
  end

  private def cache_response(cache_key : CacheKey, body : String, timeout_ms : Int32)
    now = Time.instant

    @@cache_mutex.synchronize do
      expired_keys = @@cache.compact_map do |key, entry|
        key if entry.expires_at <= now
      end
      expired_keys.each { |key| @@cache.delete(key) }

      if @@cache.size >= CACHE_LIMIT && !@@cache.has_key?(cache_key)
        oldest_key = @@cache.keys.min_by { |key| @@cache[key].expires_at }
        @@cache.delete(oldest_key)
      end

      @@cache[cache_key] = CacheEntry.new(body, now + timeout_ms.milliseconds)
    end
  end

  private def extract_polling_data(continuations : Array(JSON::Any)?) : {String?, Int32}
    continuations.try &.each do |entry|
      data = entry["invalidationContinuationData"]?
      next unless data

      continuation = continuation_from(data)
      next unless continuation

      timeout_ms = data["timeoutMs"]?.try(&.as_i?).try(&.to_i) || 10_000
      return {continuation, timeout_ms.clamp(1_000, 30_000)}
    end

    return {nil, 10_000}
  end

  private def continuation_from(data : JSON::Any?) : String?
    return data.try &.["continuation"]?.try &.as_s?
  end

  private def parse_add_action(action : JSON::Any) : Action?
    item = action.dig?("addChatItemAction", "item")
    return nil unless item

    if renderer = item["liveChatTextMessageRenderer"]?
      return parse_text_message(renderer)
    end

    if renderer = item["liveChatViewerEngagementMessageRenderer"]?
      return parse_engagement_message(renderer)
    end

    return nil
  end

  private def parse_text_message(renderer : JSON::Any) : Action?
    return nil unless renderer.as_h?

    id = renderer["id"]?.try &.as_s?
    author = extract_text(renderer["authorName"]?)
    message = extract_text(renderer["message"]?)
    return nil if author.empty? && message.empty?

    return Action.new(
      "add",
      id: id,
      kind: "text",
      author: author.empty? ? nil : author,
      message: message.empty? ? nil : message,
      badges: extract_badges(renderer),
    )
  end

  private def parse_engagement_message(renderer : JSON::Any) : Action?
    return nil unless renderer.as_h?

    message = extract_text(renderer["message"]?)
    return nil if message.empty?

    return Action.new(
      "add",
      id: renderer["id"]?.try &.as_s?,
      kind: "engagement",
      message: message,
    )
  end

  private def extract_text(value : JSON::Any?) : String
    return "" unless value

    object = value.as_h?
    return value.as_s? || "" unless object

    if simple_text = object["simpleText"]?.try &.as_s?
      return simple_text
    end

    runs = object["runs"]?.try &.as_a?
    return "" unless runs

    return String.build do |str|
      runs.each do |run|
        if text = run["text"]?.try &.as_s?
          str << text
        elsif label = run
                .dig?("emoji", "image", "accessibility", "accessibilityData", "label")
                .try &.as_s?
          str << label
        end
      end
    end
  end

  private def extract_badges(renderer : JSON::Any) : Array(String)?
    badges = renderer["authorBadges"]?.try &.as_a?
    return nil unless badges

    labels = badges.compact_map do |badge|
      badge.dig?("liveChatAuthorBadgeRenderer", "tooltip").try &.as_s?
    end

    return labels.empty? ? nil : labels
  end
end
