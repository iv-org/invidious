module Invidious::Routing
  extend self

  {% for http_method in {"get", "post", "delete", "options", "patch", "put"} %}

    macro {{http_method.id}}(path, controller, method = :handle)
      unless Kemal::Utils.path_starts_with_slash?(\{{path}})
        raise Kemal::Exceptions::InvalidPathStartException.new({{http_method}}, \{{path}})
      end

      Kemal::RouteHandler::INSTANCE.add_route({{http_method.upcase}}, \{{path}}) do |env|
        \{{ controller }}.\{{ method.id }}(env)
      end
    end

  {% end %}

  def register_all
    {% unless flag?(:api_only) %}
      get "/", Routes::Misc, :home
      get "/privacy", Routes::Misc, :privacy
      get "/licenses", Routes::Misc, :licenses
      get "/redirect", Routes::Misc, :cross_instance_redirect

      self.register_channel_routes
      self.register_watch_routes

      self.register_iv_playlist_routes
      self.register_yt_playlist_routes

      self.register_search_routes

      self.register_user_routes
      self.register_feed_routes

      # Support push notifications via PubSubHubbub
      get "/feed/webhook/:token", Routes::Feeds, :push_notifications_get
      post "/feed/webhook/:token", Routes::Feeds, :push_notifications_post

      if CONFIG.enable_user_notifications
        get "/modify_notifications", Routes::Notifications, :modify
      end
    {% end %}

    self.register_image_routes
    self.register_api_v1_routes
    self.register_api_manifest_routes
    self.register_video_playback_routes
  end

  # -------------------
  #  Invidious routes
  # -------------------

  def register_user_routes
    # User login/out
    get "/login", Routes::Login, :login_page
    post "/login", Routes::Login, :login
    post "/signout", Routes::Login, :signout

    # User preferences
    get "/preferences", Routes::PreferencesRoute, :show
    post "/preferences", Routes::PreferencesRoute, :update
    get "/toggle_theme", Routes::PreferencesRoute, :toggle_theme
    get "/data_control", Routes::PreferencesRoute, :data_control
    post "/data_control", Routes::PreferencesRoute, :update_data_control

    # User account management
    get "/change_password", Routes::Account, :get_change_password
    post "/change_password", Routes::Account, :post_change_password
    get "/delete_account", Routes::Account, :get_delete
    post "/delete_account", Routes::Account, :post_delete
    get "/clear_watch_history", Routes::Account, :get_clear_history
    post "/clear_watch_history", Routes::Account, :post_clear_history
    get "/authorize_token", Routes::Account, :get_authorize_token
    post "/authorize_token", Routes::Account, :post_authorize_token
    get "/token_manager", Routes::Account, :token_manager
    post "/token_ajax", Routes::Account, :token_ajax
    post "/subscription_ajax", Routes::Subscriptions, :toggle_subscription
    get "/subscription_manager", Routes::Subscriptions, :subscription_manager
  end

  def register_iv_playlist_routes
    get "/create_playlist", Routes::Playlists, :new
    post "/create_playlist", Routes::Playlists, :create
    get "/subscribe_playlist", Routes::Playlists, :subscribe
    get "/delete_playlist", Routes::Playlists, :delete_page
    post "/delete_playlist", Routes::Playlists, :delete
    get "/edit_playlist", Routes::Playlists, :edit
    post "/edit_playlist", Routes::Playlists, :update
    get "/add_playlist_items", Routes::Playlists, :add_playlist_items_page
    post "/playlist_ajax", Routes::Playlists, :playlist_ajax
  end

  def register_feed_routes
    # Feeds
    get "/view_all_playlists", Routes::Feeds, :view_all_playlists_redirect
    get "/feed/playlists", Routes::Feeds, :playlists
    get "/feed/popular", Routes::Feeds, :popular
    get "/feed/trending", Routes::Feeds, :trending
    get "/feed/subscriptions", Routes::Feeds, :subscriptions
    get "/feed/history", Routes::Feeds, :history

    # RSS Feeds
    get "/feed/channel/:ucid", Routes::Feeds, :rss_channel
    get "/feed/private", Routes::Feeds, :rss_private
    get "/feed/playlist/:plid", Routes::Feeds, :rss_playlist
    get "/feeds/videos.xml", Routes::Feeds, :rss_videos
  end

  # -------------------
  #  Youtube routes
  # -------------------

  def register_channel_routes
    get "/channel/:ucid", Routes::Channels, :home
    get "/channel/:ucid/home", Routes::Channels, :home
    get "/channel/:ucid/videos", Routes::Channels, :videos
    get "/channel/:ucid/shorts", Routes::Channels, :shorts
    get "/channel/:ucid/streams", Routes::Channels, :streams
    get "/channel/:ucid/playlists", Routes::Channels, :playlists
    get "/channel/:ucid/community", Routes::Channels, :community
    get "/channel/:ucid/channels", Routes::Channels, :channels
    get "/channel/:ucid/about", Routes::Channels, :about
    get "/channel/:ucid/live", Routes::Channels, :live
    get "/user/:user/live", Routes::Channels, :live
    get "/c/:user/live", Routes::Channels, :live

    {"", "/videos", "/shorts", "/streams", "/playlists", "/community", "/about"}.each do |path|
      # /c/LinusTechTips
      get "/c/:user#{path}", Routes::Channels, :brand_redirect
      # /user/linustechtips | Not always the same as /c/
      get "/user/:user#{path}", Routes::Channels, :brand_redirect
      # /@LinusTechTips | Handle
      get "/@:user#{path}", Routes::Channels, :brand_redirect
      # /attribution_link?a=anything&u=/channel/UCZYTClx2T1of7BRZ86-8fow
      get "/attribution_link#{path}", Routes::Channels, :brand_redirect
      # /profile?user=linustechtips
      get "/profile/#{path}", Routes::Channels, :profile
    end
  end

  def register_watch_routes
    get "/watch", Routes::Watch, :handle
    post "/watch_ajax", Routes::Watch, :mark_watched
    get "/watch/:id", Routes::Watch, :redirect
    get "/shorts/:id", Routes::Watch, :redirect
    get "/clip/:clip", Routes::Watch, :clip
    get "/w/:id", Routes::Watch, :redirect
    get "/v/:id", Routes::Watch, :redirect
    get "/e/:id", Routes::Watch, :redirect

    post "/download", Routes::Watch, :download

    get "/embed/", Routes::Embed, :redirect
    get "/embed/:id", Routes::Embed, :show
  end

  def register_yt_playlist_routes
    get "/playlist", Routes::Playlists, :show
    get "/mix", Routes::Playlists, :mix
    get "/watch_videos", Routes::Playlists, :watch_videos
  end

  def register_search_routes
    get "/opensearch.xml", Routes::Search, :opensearch
    get "/results", Routes::Search, :results
    get "/search", Routes::Search, :search
    get "/hashtag/:hashtag", Routes::Search, :hashtag
  end

  # -------------------
  #  Media proxy routes
  # -------------------

  def register_api_manifest_routes
    get "/api/manifest/dash/id/:id", Routes::API::Manifest, :get_dash_video_id

    get "/api/manifest/dash/id/videoplayback", Routes::API::Manifest, :get_dash_video_playback
    get "/api/manifest/dash/id/videoplayback/*", Routes::API::Manifest, :get_dash_video_playback_greedy

    options "/api/manifest/dash/id/videoplayback", Routes::API::Manifest, :options_dash_video_playback
    options "/api/manifest/dash/id/videoplayback/*", Routes::API::Manifest, :options_dash_video_playback

    get "/api/manifest/hls_playlist/*", Routes::API::Manifest, :get_hls_playlist
    get "/api/manifest/hls_variant/*", Routes::API::Manifest, :get_hls_variant
  end

  def register_video_playback_routes
    get "/videoplayback", Routes::VideoPlayback, :get_video_playback
    get "/videoplayback/*", Routes::VideoPlayback, :get_video_playback_greedy

    options "/videoplayback", Routes::VideoPlayback, :options_video_playback
    options "/videoplayback/*", Routes::VideoPlayback, :options_video_playback

    get "/latest_version", Routes::VideoPlayback, :latest_version
  end

  def register_image_routes
    get "/ggpht/*", Routes::Images, :ggpht
    options "/sb/:authority/:id/:storyboard/:index", Routes::Images, :options_storyboard
    get "/sb/:authority/:id/:storyboard/:index", Routes::Images, :get_storyboard
    get "/s_p/:id/:name", Routes::Images, :s_p_image
    get "/yts/img/:name", Routes::Images, :yts_image
    get "/vi/:id/:name", Routes::Images, :thumbnails
  end

  # -------------------
  #  API routes
  # -------------------

  def register_api_v1_routes
    {% begin %}
      {{namespace = Routes::API::V1}}

      # Videos
      get "/api/v1/videos/:id", {{namespace}}::Videos, :videos
      get "/api/v1/storyboards/:id", {{namespace}}::Videos, :storyboards
      get "/api/v1/captions/:id", {{namespace}}::Videos, :captions
      get "/api/v1/annotations/:id", {{namespace}}::Videos, :annotations
      get "/api/v1/comments/:id", {{namespace}}::Videos, :comments

      # Feeds
      get "/api/v1/trending", {{namespace}}::Feeds, :trending
      get "/api/v1/popular", {{namespace}}::Feeds, :popular

      # Channels
      get "/api/v1/channels/:ucid", {{namespace}}::Channels, :home
      get "/api/v1/channels/:ucid/shorts", {{namespace}}::Channels, :shorts
      get "/api/v1/channels/:ucid/streams", {{namespace}}::Channels, :streams
      get "/api/v1/channels/:ucid/channels", {{namespace}}::Channels, :channels

      {% for route in {"videos", "latest", "playlists", "community", "search"} %}
        get "/api/v1/channels/#{{{route}}}/:ucid", {{namespace}}::Channels, :{{route}}
        get "/api/v1/channels/:ucid/#{{{route}}}", {{namespace}}::Channels, :{{route}}
      {% end %}

      # 301 redirects to new /api/v1/channels/community/:ucid and /:ucid/community
      get "/api/v1/channels/comments/:ucid", {{namespace}}::Channels, :channel_comments_redirect
      get "/api/v1/channels/:ucid/comments", {{namespace}}::Channels, :channel_comments_redirect

      # Search
      get "/api/v1/search", {{namespace}}::Search, :search
      get "/api/v1/search/suggestions", {{namespace}}::Search, :search_suggestions
      get "/api/v1/hashtag/:hashtag", {{namespace}}::Search, :hashtag

      # Authenticated

      # The notification APIs cannot be extracted yet! They require the *local* notifications constant defined in invidious.cr
      #
      # Invidious::Routing.get "/api/v1/auth/notifications", {{namespace}}::Authenticated, :notifications
      # Invidious::Routing.post "/api/v1/auth/notifications", {{namespace}}::Authenticated, :notifications

      get "/api/v1/auth/preferences", {{namespace}}::Authenticated, :get_preferences
      post "/api/v1/auth/preferences", {{namespace}}::Authenticated, :set_preferences

      get "/api/v1/auth/export/invidious", {{namespace}}::Authenticated, :export_invidious
      post "/api/v1/auth/import/invidious", {{namespace}}::Authenticated, :import_invidious

      get "/api/v1/auth/history", {{namespace}}::Authenticated, :get_history
      post "/api/v1/auth/history/:id", {{namespace}}::Authenticated, :mark_watched
      delete "/api/v1/auth/history/:id", {{namespace}}::Authenticated, :mark_unwatched
      delete "/api/v1/auth/history", {{namespace}}::Authenticated, :clear_history

      get "/api/v1/auth/feed", {{namespace}}::Authenticated, :feed

      get "/api/v1/auth/subscriptions", {{namespace}}::Authenticated, :get_subscriptions
      post "/api/v1/auth/subscriptions/:ucid", {{namespace}}::Authenticated, :subscribe_channel
      delete "/api/v1/auth/subscriptions/:ucid", {{namespace}}::Authenticated, :unsubscribe_channel

      get "/api/v1/auth/playlists", {{namespace}}::Authenticated, :list_playlists
      post "/api/v1/auth/playlists", {{namespace}}::Authenticated, :create_playlist
      patch "/api/v1/auth/playlists/:plid",{{namespace}}:: Authenticated, :update_playlist_attribute
      delete "/api/v1/auth/playlists/:plid", {{namespace}}::Authenticated, :delete_playlist
      post "/api/v1/auth/playlists/:plid/videos", {{namespace}}::Authenticated, :insert_video_into_playlist
      delete "/api/v1/auth/playlists/:plid/videos/:index", {{namespace}}::Authenticated, :delete_video_in_playlist

      get "/api/v1/auth/tokens", {{namespace}}::Authenticated, :get_tokens
      post "/api/v1/auth/tokens/register", {{namespace}}::Authenticated, :register_token
      post "/api/v1/auth/tokens/unregister", {{namespace}}::Authenticated, :unregister_token

      if CONFIG.enable_user_notifications
        get "/api/v1/auth/notifications", {{namespace}}::Authenticated, :notifications
        post "/api/v1/auth/notifications", {{namespace}}::Authenticated, :notifications
      end

      # Misc
      get "/api/v1/stats", {{namespace}}::Misc, :stats
      get "/api/v1/playlists/:plid", {{namespace}}::Misc, :get_playlist
      get "/api/v1/auth/playlists/:plid", {{namespace}}::Misc, :get_playlist
      get "/api/v1/mixes/:rdid", {{namespace}}::Misc, :mixes
      get "/api/v1/resolveurl", {{namespace}}::Misc, :resolve_url
    {% end %}
  end
end
