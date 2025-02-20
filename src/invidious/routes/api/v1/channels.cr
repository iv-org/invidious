module Invidious::Routes::API::V1::Channels
  # Macro to avoid duplicating some code below
  # This sets the `channel` variable, or handles Exceptions.
  private macro get_channel
    begin
      channel = get_about_info(ucid, locale)
    rescue ex : ChannelRedirect
      env.response.headers["Location"] = env.request.resource.gsub(ucid, ex.channel_id)
      return error_json(302, "Channel is unavailable", {"authorId" => ex.channel_id})
    rescue ex : NotFoundException
      return error_json(404, ex)
    rescue ex
      return error_json(500, ex)
    end
  end

  def self.home(env)
    locale = env.get("preferences").as(Preferences).locale
    ucid = env.params.url["ucid"]

    env.response.content_type = "application/json"

    # Use the private macro defined above.
    channel = nil # Make the compiler happy
    get_channel()

    # Retrieve "sort by" setting from URL parameters
    sort_by = env.params.query["sort_by"]?.try &.downcase || "newest"

    if channel.is_age_gated
      begin
        playlist = get_playlist(channel.ucid.sub("UC", "UULF"))
        videos = get_playlist_videos(playlist, offset: 0)
      rescue ex : InfoException
        # playlist doesnt exist.
        videos = [] of PlaylistVideo
      end
      next_continuation = nil
    else
      begin
        videos, _ = Channel::Tabs.get_videos(channel, sort_by: sort_by)
      rescue ex
        return error_json(500, ex)
      end
    end

    JSON.build do |json|
      # TODO: Refactor into `to_json` for InvidiousChannel
      json.object do
        json.field "author", channel.author
        json.field "authorId", channel.ucid
        json.field "authorUrl", channel.author_url

        json.field "authorBanners" do
          json.array do
            if channel.banner
              qualities = {
                {width: 2560, height: 424},
                {width: 2120, height: 351},
                {width: 1060, height: 175},
              }
              qualities.each do |quality|
                json.object do
                  json.field "url", channel.banner.not_nil!.gsub("=w1060-", "=w#{quality[:width]}-")
                  json.field "width", quality[:width]
                  json.field "height", quality[:height]
                end
              end

              json.object do
                json.field "url", channel.banner.not_nil!.split("=w1060-")[0]
                json.field "width", 512
                json.field "height", 288
              end
            end
          end
        end

        json.field "authorThumbnails" do
          json.array do
            qualities = {32, 48, 76, 100, 176, 512}

            qualities.each do |quality|
              json.object do
                json.field "url", channel.author_thumbnail.gsub(/=s\d+/, "=s#{quality}")
                json.field "width", quality
                json.field "height", quality
              end
            end
          end
        end

        json.field "subCount", channel.sub_count
        json.field "totalViews", channel.total_views
        json.field "joined", channel.joined.to_unix

        json.field "autoGenerated", channel.auto_generated
        json.field "ageGated", channel.is_age_gated
        json.field "isFamilyFriendly", channel.is_family_friendly
        json.field "description", html_to_content(channel.description_html)
        json.field "descriptionHtml", channel.description_html

        json.field "allowedRegions", channel.allowed_regions
        json.field "tabs", channel.tabs
        json.field "tags", channel.tags
        json.field "authorVerified", channel.verified

        json.field "latestVideos" do
          json.array do
            videos.each do |video|
              video.to_json(locale, json)
            end
          end
        end

        json.field "relatedChannels" do
          json.array do
            # Fetch related channels
            begin
              related_channels, _ = fetch_related_channels(channel)
            rescue ex
              related_channels = [] of SearchChannel
            end

            related_channels.each do |related_channel|
              related_channel.to_json(locale, json)
            end
          end
        end # relatedChannels

      end
    end
  end

  def self.latest(env)
    # Remove parameters that could affect this endpoint's behavior
    env.params.query.delete("sort_by") if env.params.query.has_key?("sort_by")
    env.params.query.delete("continuation") if env.params.query.has_key?("continuation")

    return self.videos(env)
  end

  def self.videos(env)
    locale = env.get("preferences").as(Preferences).locale
    ucid = env.params.url["ucid"]

    env.response.content_type = "application/json"

    # Use the private macro defined above.
    channel = nil # Make the compiler happy
    get_channel()

    # Retrieve some URL parameters
    sort_by = env.params.query["sort_by"]?.try &.downcase || "newest"
    continuation = env.params.query["continuation"]?

    if channel.is_age_gated
      begin
        playlist = get_playlist(channel.ucid.sub("UC", "UULF"))
        videos = get_playlist_videos(playlist, offset: 0)
      rescue ex : InfoException
        # playlist doesnt exist.
        videos = [] of PlaylistVideo
      end
      next_continuation = nil
    else
      begin
        videos, next_continuation = Channel::Tabs.get_60_videos(
          channel, continuation: continuation, sort_by: sort_by
        )
      rescue ex
        return error_json(500, ex)
      end
    end

    return JSON.build do |json|
      json.object do
        json.field "videos" do
          json.array do
            videos.each &.to_json(locale, json)
          end
        end

        json.field "continuation", next_continuation if next_continuation
      end
    end
  end

  def self.shorts(env)
    locale = env.get("preferences").as(Preferences).locale
    ucid = env.params.url["ucid"]

    env.response.content_type = "application/json"

    # Use the private macro defined above.
    channel = nil # Make the compiler happy
    get_channel()

    # Retrieve continuation from URL parameters
    sort_by = env.params.query["sort_by"]?.try &.downcase || "newest"
    continuation = env.params.query["continuation"]?

    if channel.is_age_gated
      begin
        playlist = get_playlist(channel.ucid.sub("UC", "UUSH"))
        videos = get_playlist_videos(playlist, offset: 0)
      rescue ex : InfoException
        # playlist doesnt exist.
        videos = [] of PlaylistVideo
      end
      next_continuation = nil
    else
      begin
        videos, next_continuation = Channel::Tabs.get_shorts(
          channel, continuation: continuation, sort_by: sort_by
        )
      rescue ex
        return error_json(500, ex)
      end
    end

    return JSON.build do |json|
      json.object do
        json.field "videos" do
          json.array do
            videos.each &.to_json(locale, json)
          end
        end

        json.field "continuation", next_continuation if next_continuation
      end
    end
  end

  def self.streams(env)
    locale = env.get("preferences").as(Preferences).locale
    ucid = env.params.url["ucid"]

    env.response.content_type = "application/json"

    # Use the private macro defined above.
    channel = nil # Make the compiler happy
    get_channel()

    # Retrieve continuation from URL parameters
    sort_by = env.params.query["sort_by"]?.try &.downcase || "newest"
    continuation = env.params.query["continuation"]?

    if channel.is_age_gated
      begin
        playlist = get_playlist(channel.ucid.sub("UC", "UULV"))
        videos = get_playlist_videos(playlist, offset: 0)
      rescue ex : InfoException
        # playlist doesnt exist.
        videos = [] of PlaylistVideo
      end
      next_continuation = nil
    else
      begin
        videos, next_continuation = Channel::Tabs.get_60_livestreams(
          channel, continuation: continuation, sort_by: sort_by
        )
      rescue ex
        return error_json(500, ex)
      end
    end

    return JSON.build do |json|
      json.object do
        json.field "videos" do
          json.array do
            videos.each &.to_json(locale, json)
          end
        end

        json.field "continuation", next_continuation if next_continuation
      end
    end
  end

  def self.playlists(env)
    locale = env.get("preferences").as(Preferences).locale

    env.response.content_type = "application/json"

    ucid = env.params.url["ucid"]
    continuation = env.params.query["continuation"]?
    sort_by = env.params.query["sort"]?.try &.downcase ||
              env.params.query["sort_by"]?.try &.downcase ||
              "last"

    # Use the macro defined above
    channel = nil # Make the compiler happy
    get_channel()

    items, next_continuation = fetch_channel_playlists(channel.ucid, channel.author, continuation, sort_by)

    JSON.build do |json|
      json.object do
        json.field "playlists" do
          json.array do
            items.each do |item|
              item.to_json(locale, json) if item.is_a?(SearchPlaylist)
            end
          end
        end

        json.field "continuation", next_continuation if next_continuation
      end
    end
  end

  def self.podcasts(env)
    locale = env.get("preferences").as(Preferences).locale

    env.response.content_type = "application/json"

    ucid = env.params.url["ucid"]
    continuation = env.params.query["continuation"]?

    # Use the macro defined above
    channel = nil # Make the compiler happy
    get_channel()

    items, next_continuation = fetch_channel_podcasts(channel.ucid, channel.author, continuation)

    JSON.build do |json|
      json.object do
        json.field "playlists" do
          json.array do
            items.each do |item|
              item.to_json(locale, json) if item.is_a?(SearchPlaylist)
            end
          end
        end

        json.field "continuation", next_continuation if next_continuation
      end
    end
  end

  def self.releases(env)
    locale = env.get("preferences").as(Preferences).locale

    env.response.content_type = "application/json"

    ucid = env.params.url["ucid"]
    continuation = env.params.query["continuation"]?

    # Use the macro defined above
    channel = nil # Make the compiler happy
    get_channel()

    items, next_continuation = fetch_channel_releases(channel.ucid, channel.author, continuation)

    JSON.build do |json|
      json.object do
        json.field "playlists" do
          json.array do
            items.each do |item|
              item.to_json(locale, json) if item.is_a?(SearchPlaylist)
            end
          end
        end

        json.field "continuation", next_continuation if next_continuation
      end
    end
  end

  def self.community(env)
    locale = env.get("preferences").as(Preferences).locale
    include_youtube_links = env.get("preferences").as(Preferences).include_youtube_links

    env.response.content_type = "application/json"

    ucid = env.params.url["ucid"]

    thin_mode = env.params.query["thin_mode"]?
    thin_mode = thin_mode == "true"

    format = env.params.query["format"]?
    format ||= "json"

    continuation = env.params.query["continuation"]?
    # sort_by = env.params.query["sort_by"]?.try &.downcase

    begin
      fetch_channel_community(ucid, continuation, locale, format, thin_mode, include_youtube_links)
    rescue ex
      return error_json(500, ex)
    end
  end

  def self.post(env)
    locale = env.get("preferences").as(Preferences).locale
    include_youtube_links = env.get("preferences").as(Preferences).include_youtube_links

    env.response.content_type = "application/json"
    id = env.params.url["id"].to_s
    ucid = env.params.query["ucid"]?

    thin_mode = env.params.query["thin_mode"]?
    thin_mode = thin_mode == "true"

    format = env.params.query["format"]?
    format ||= "json"

    if ucid.nil?
      response = YoutubeAPI.resolve_url("https://www.youtube.com/post/#{id}")
      return error_json(400, "Invalid post ID") if response["error"]?
      ucid = response.dig("endpoint", "browseEndpoint", "browseId").as_s
    else
      ucid = ucid.to_s
    end

    begin
      fetch_channel_community_post(ucid, id, locale, format, thin_mode, include_youtube_links)
    rescue ex
      return error_json(500, ex)
    end
  end

  def self.post_comments(env)
    locale = env.get("preferences").as(Preferences).locale
    include_youtube_links = env.get("preferences").as(Preferences).include_youtube_links

    env.response.content_type = "application/json"

    id = env.params.url["id"]

    thin_mode = env.params.query["thin_mode"]?
    thin_mode = thin_mode == "true"

    format = env.params.query["format"]?
    format ||= "json"

    continuation = env.params.query["continuation"]?

    case continuation
    when nil, ""
      ucid = env.params.query["ucid"]
      comments = Comments.fetch_community_post_comments(ucid, id)
    else
      comments = YoutubeAPI.browse(continuation: continuation)
    end
    return Comments.parse_youtube(id, comments, format, locale, thin_mode, include_youtube_links, is_post: true)
  end

  def self.channels(env)
    locale = env.get("preferences").as(Preferences).locale
    ucid = env.params.url["ucid"]

    env.response.content_type = "application/json"

    # Use the macro defined above
    channel = nil # Make the compiler happy
    get_channel()

    continuation = env.params.query["continuation"]?

    begin
      items, next_continuation = fetch_related_channels(channel, continuation)
    rescue ex
      return error_json(500, ex)
    end

    JSON.build do |json|
      json.object do
        json.field "relatedChannels" do
          json.array do
            items.each &.to_json(locale, json)
          end
        end

        json.field "continuation", next_continuation if next_continuation
      end
    end
  end

  def self.search(env)
    locale = env.get("preferences").as(Preferences).locale
    region = env.params.query["region"]?

    env.response.content_type = "application/json"

    query = Invidious::Search::Query.new(env.params.query, :channel, region)

    # Required because we can't (yet) pass multiple parameter to the
    # `Search::Query` initializer (in this case, an URL segment)
    query.channel = env.params.url["ucid"]

    begin
      search_results = query.process
    rescue ex
      return error_json(400, ex)
    end

    JSON.build do |json|
      json.array do
        search_results.each do |item|
          item.to_json(locale, json)
        end
      end
    end
  end

  # 301 redirect from /api/v1/channels/comments/:ucid
  # and /api/v1/channels/:ucid/comments to new /api/v1/channels/:ucid/community and
  # corresponding equivalent URL structure of the other one.
  def self.channel_comments_redirect(env)
    env.response.content_type = "application/json"
    ucid = env.params.url["ucid"]

    env.response.headers["Location"] = "/api/v1/channels/#{ucid}/community?#{env.params.query}"
    env.response.status_code = 301
    return
  end
end
