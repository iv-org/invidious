module Invidious::Routing
  extend self

  {% for http_method in {"get", "post", "delete", "options", "patch", "put"} %}

    macro {{http_method.id}}(path, controller, method = :handle)
      {{http_method.id}} \{{ path }} do |env|
        \{{ controller }}.\{{ method.id }}(env)
      end
    end

  {% end %}

  # -------------------
  #  Invidious routes
  # -------------------

  def register_user_routes
    # User login/out
    get "/login", Routes::Login, :login_page
    post "/login", Routes::Login, :login
    post "/signout", Routes::Login, :signout
    get "/Captcha", Routes::Login, :captcha

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

  # -------------------
  #  Youtube routes
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

      # Authenticated

      # The notification APIs cannot be extracted yet! They require the *local* notifications constant defined in invidious.cr
      #
      # Invidious::Routing.get "/api/v1/auth/notifications", {{namespace}}::Authenticated, :notifications
      # Invidious::Routing.post "/api/v1/auth/notifications", {{namespace}}::Authenticated, :notifications

      get "/api/v1/auth/preferences", {{namespace}}::Authenticated, :get_preferences
      post "/api/v1/auth/preferences", {{namespace}}::Authenticated, :set_preferences

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

      get "/api/v1/auth/notifications", {{namespace}}::Authenticated, :notifications
      post "/api/v1/auth/notifications", {{namespace}}::Authenticated, :notifications

      # Misc
      get "/api/v1/stats", {{namespace}}::Misc, :stats
      get "/api/v1/playlists/:plid", {{namespace}}::Misc, :get_playlist
      get "/api/v1/auth/playlists/:plid", {{namespace}}::Misc, :get_playlist
      get "/api/v1/mixes/:rdid", {{namespace}}::Misc, :mixes
    {% end %}
  end
end
