module Invidious::Routing
  {% for http_method in {"get", "post", "delete", "options", "patch", "put", "head"} %}

    macro {{http_method.id}}(path, controller, method = :handle)
      {{http_method.id}} \{{ path }} do |env|
        \{{ controller }}.\{{ method.id }}(env)
      end
    end

  {% end %}
end

macro define_user_routes
  # User login/out
  Invidious::Routing.get "/login", Invidious::Routes::Login, :login_page
  Invidious::Routing.post "/login", Invidious::Routes::Login, :login
  Invidious::Routing.post "/signout", Invidious::Routes::Login, :signout
  Invidious::Routing.get "/Captcha", Invidious::Routes::Login, :captcha

  # User preferences
  Invidious::Routing.get "/preferences", Invidious::Routes::PreferencesRoute, :show
  Invidious::Routing.post "/preferences", Invidious::Routes::PreferencesRoute, :update
  Invidious::Routing.get "/toggle_theme", Invidious::Routes::PreferencesRoute, :toggle_theme
  Invidious::Routing.get "/data_control", Invidious::Routes::PreferencesRoute, :data_control
  Invidious::Routing.post "/data_control", Invidious::Routes::PreferencesRoute, :update_data_control

  # User account management
  Invidious::Routing.get "/change_password", Invidious::Routes::Account, :get_change_password
  Invidious::Routing.post "/change_password", Invidious::Routes::Account, :post_change_password
  Invidious::Routing.get "/delete_account", Invidious::Routes::Account, :get_delete
  Invidious::Routing.post "/delete_account", Invidious::Routes::Account, :post_delete
  Invidious::Routing.get "/clear_watch_history", Invidious::Routes::Account, :get_clear_history
  Invidious::Routing.post "/clear_watch_history", Invidious::Routes::Account, :post_clear_history
  Invidious::Routing.get "/authorize_token", Invidious::Routes::Account, :get_authorize_token
  Invidious::Routing.post "/authorize_token", Invidious::Routes::Account, :post_authorize_token
  Invidious::Routing.get "/token_manager", Invidious::Routes::Account, :token_manager
  Invidious::Routing.post "/token_ajax", Invidious::Routes::Account, :token_ajax
end

macro define_v1_api_routes
  {{namespace = Invidious::Routes::API::V1}}
  # Videos
  Invidious::Routing.get "/api/v1/videos/:id", {{namespace}}::Videos, :videos
  Invidious::Routing.get "/api/v1/storyboards/:id", {{namespace}}::Videos, :storyboards
  Invidious::Routing.get "/api/v1/captions/:id", {{namespace}}::Videos, :captions
  Invidious::Routing.get "/api/v1/annotations/:id", {{namespace}}::Videos, :annotations
  Invidious::Routing.get "/api/v1/comments/:id", {{namespace}}::Videos, :comments

  # Feeds
  Invidious::Routing.get "/api/v1/trending", {{namespace}}::Feeds, :trending
  Invidious::Routing.get "/api/v1/popular", {{namespace}}::Feeds, :popular

  # Channels
  Invidious::Routing.get "/api/v1/channels/:ucid", {{namespace}}::Channels, :home
  {% for route in {"videos", "latest", "playlists", "community", "search"} %}
    Invidious::Routing.get "/api/v1/channels/#{{{route}}}/:ucid", {{namespace}}::Channels, :{{route}}
    Invidious::Routing.get "/api/v1/channels/:ucid/#{{{route}}}", {{namespace}}::Channels, :{{route}}
  {% end %}

  # 301 redirects to new /api/v1/channels/community/:ucid and /:ucid/community
  Invidious::Routing.get "/api/v1/channels/comments/:ucid", {{namespace}}::Channels, :channel_comments_redirect
  Invidious::Routing.get "/api/v1/channels/:ucid/comments", {{namespace}}::Channels, :channel_comments_redirect


  # Search
  Invidious::Routing.get "/api/v1/search", {{namespace}}::Search, :search
  Invidious::Routing.get "/api/v1/search/suggestions", {{namespace}}::Search, :search_suggestions

  # Authenticated

  # The notification APIs cannot be extracted yet! They require the *local* notifications constant defined in invidious.cr
  #
  # Invidious::Routing.get "/api/v1/auth/notifications", {{namespace}}::Authenticated, :notifications
  # Invidious::Routing.post "/api/v1/auth/notifications", {{namespace}}::Authenticated, :notifications

  Invidious::Routing.get "/api/v1/auth/preferences", {{namespace}}::Authenticated, :get_preferences
  Invidious::Routing.post "/api/v1/auth/preferences", {{namespace}}::Authenticated, :set_preferences

  Invidious::Routing.get "/api/v1/auth/feed", {{namespace}}::Authenticated, :feed

  Invidious::Routing.get "/api/v1/auth/subscriptions", {{namespace}}::Authenticated, :get_subscriptions
  Invidious::Routing.post "/api/v1/auth/subscriptions/:ucid", {{namespace}}::Authenticated, :subscribe_channel
  Invidious::Routing.delete "/api/v1/auth/subscriptions/:ucid", {{namespace}}::Authenticated, :unsubscribe_channel


  Invidious::Routing.get "/api/v1/auth/playlists", {{namespace}}::Authenticated, :list_playlists
  Invidious::Routing.post "/api/v1/auth/playlists", {{namespace}}::Authenticated, :create_playlist
  Invidious::Routing.patch "/api/v1/auth/playlists/:plid",{{namespace}}:: Authenticated, :update_playlist_attribute
  Invidious::Routing.delete "/api/v1/auth/playlists/:plid", {{namespace}}::Authenticated, :delete_playlist


  Invidious::Routing.post "/api/v1/auth/playlists/:plid/videos", {{namespace}}::Authenticated, :insert_video_into_playlist
  Invidious::Routing.delete "/api/v1/auth/playlists/:plid/videos/:index", {{namespace}}::Authenticated, :delete_video_in_playlist

  Invidious::Routing.get "/api/v1/auth/tokens", {{namespace}}::Authenticated, :get_tokens
  Invidious::Routing.post "/api/v1/auth/tokens/register", {{namespace}}::Authenticated, :register_token
  Invidious::Routing.post "/api/v1/auth/tokens/unregister", {{namespace}}::Authenticated, :unregister_token

  Invidious::Routing.get "/api/v1/auth/notifications", {{namespace}}::Authenticated, :notifications
  Invidious::Routing.post "/api/v1/auth/notifications", {{namespace}}::Authenticated, :notifications

  # Misc
  Invidious::Routing.get "/api/v1/stats", {{namespace}}::Misc, :stats
  Invidious::Routing.get "/api/v1/playlists/:plid", {{namespace}}::Misc, :get_playlist
  Invidious::Routing.get "/api/v1/auth/playlists/:plid", {{namespace}}::Misc, :get_playlist
  Invidious::Routing.get "/api/v1/mixes/:rdid", {{namespace}}::Misc, :mixes
end

macro define_api_manifest_routes
  Invidious::Routing.get "/api/manifest/dash/id/:id", Invidious::Routes::API::Manifest, :get_dash_video_id

  Invidious::Routing.get "/api/manifest/dash/id/videoplayback", Invidious::Routes::API::Manifest, :get_dash_video_playback
  Invidious::Routing.get "/api/manifest/dash/id/videoplayback/*", Invidious::Routes::API::Manifest, :get_dash_video_playback_greedy

  Invidious::Routing.options "/api/manifest/dash/id/videoplayback", Invidious::Routes::API::Manifest, :options_dash_video_playback
  Invidious::Routing.options "/api/manifest/dash/id/videoplayback/*", Invidious::Routes::API::Manifest, :options_dash_video_playback

  Invidious::Routing.get "/api/manifest/hls_playlist/*", Invidious::Routes::API::Manifest, :get_hls_playlist
  Invidious::Routing.get "/api/manifest/hls_variant/*", Invidious::Routes::API::Manifest, :get_hls_variant
end

macro define_video_playback_routes
  Invidious::Routing.get "/videoplayback", Invidious::Routes::VideoPlayback, :get_video_playback
  Invidious::Routing.get "/videoplayback/*", Invidious::Routes::VideoPlayback, :get_video_playback_greedy

  Invidious::Routing.options "/videoplayback", Invidious::Routes::VideoPlayback, :options_video_playback
  Invidious::Routing.options "/videoplayback/*", Invidious::Routes::VideoPlayback, :options_video_playback

  Invidious::Routing.get "/latest_version", Invidious::Routes::VideoPlayback, :latest_version
end
