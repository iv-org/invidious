# There is far too many API routes to define in invidious.cr
# so we'll just do it here instead with a macro.
macro define_v1_api_routes(base_url = "/api/v1")
  # Videos
  Invidious::Routing.get "#{{{base_url}}}/videos/:id", Invidious::Routes::APIv1::Videos, :videos
  Invidious::Routing.get "#{{{base_url}}}/storyboards/:id", Invidious::Routes::APIv1::Videos, :storyboards
  Invidious::Routing.get "#{{{base_url}}}/captions/:id", Invidious::Routes::APIv1::Videos, :captions
  Invidious::Routing.get "#{{{base_url}}}/annotations/:id", Invidious::Routes::APIv1::Videos, :annotations
  Invidious::Routing.get "#{{{base_url}}}/comments/:id", Invidious::Routes::APIv1::Videos, :comments

  # Feeds
  Invidious::Routing.get "#{{{base_url}}}/trending", Invidious::Routes::APIv1::Feeds, :trending
  Invidious::Routing.get "#{{{base_url}}}/popular", Invidious::Routes::APIv1::Feeds, :popular

  # Channels
  Invidious::Routing.get "#{{{base_url}}}/channels/:ucid", Invidious::Routes::APIv1::Channels, :home
  {% for route in {
                    {"home", "home"},
                    {"videos", "videos"},
                    {"latest", "latest"},
                    {"playlists", "playlists"},
                    {"comments", "community"}, # Why is the route for the community API `comments`?,
                    {"search", "channel_search"},
                  } %}

  Invidious::Routing.get "#{{{base_url}}}/channels/#{{{route[0]}}}/:ucid", Invidious::Routes::APIv1::Channels, :{{route[1]}}
  Invidious::Routing.get "#{{{base_url}}}/channels/:ucid/#{{{route[0]}}}", Invidious::Routes::APIv1::Channels, :{{route[1]}}
  {% end %}

  # Search
  Invidious::Routing.get "#{{{base_url}}}/search", Invidious::Routes::APIv1::Search, :search
  Invidious::Routing.get "#{{{base_url}}}/search/suggestions/:id", Invidious::Routes::APIv1::Search, :search_suggestions

  # Authenticated
  # Invidious::Routing.get "#{{{base_url}}}/auth/notifications", Invidious::Routes::APIv1::Authenticated, :notifications
  # Invidious::Routing.post "#{{{base_url}}}/auth/notifications", Invidious::Routes::APIv1::Authenticated, :notifications

  Invidious::Routing.get "#{{{base_url}}}/auth/preferences", Invidious::Routes::APIv1::Authenticated, :get_preferences
  Invidious::Routing.post "#{{{base_url}}}/auth/preferences", Invidious::Routes::APIv1::Authenticated, :set_preferences

  Invidious::Routing.get "#{{{base_url}}}/auth/feed", Invidious::Routes::APIv1::Authenticated, :feed

  Invidious::Routing.get "#{{{base_url}}}/auth/subscriptions", Invidious::Routes::APIv1::Authenticated, :get_subscriptions
  Invidious::Routing.post "#{{{base_url}}}/auth/subscriptions/:ucid", Invidious::Routes::APIv1::Authenticated, :subscribe_channel
  Invidious::Routing.delete "#{{{base_url}}}/auth/subscriptions/:ucid", Invidious::Routes::APIv1::Authenticated, :unsubscribe_channel


  Invidious::Routing.get "#{{{base_url}}}/auth/playlists", Invidious::Routes::APIv1::Authenticated, :list_playlists
  Invidious::Routing.post "#{{{base_url}}}/auth/playlists", Invidious::Routes::APIv1::Authenticated, :create_playlist
  Invidious::Routing.patch "#{{{base_url}}}/auth/playlists/:ucid", Invidious::Routes::APIv1::Authenticated, :update_playlist_attribute
  Invidious::Routing.delete "#{{{base_url}}}/auth/playlists/:ucid", Invidious::Routes::APIv1::Authenticated, :delete_playlist


  Invidious::Routing.post "#{{{base_url}}}/auth/playlists/:ucid/videos", Invidious::Routes::APIv1::Authenticated, :insert_video_into_playlist
  Invidious::Routing.delete "#{{{base_url}}}/auth/playlists/:ucid/videos/:index", Invidious::Routes::APIv1::Authenticated, :delete_video_in_playlist

  Invidious::Routing.get "#{{{base_url}}}/auth/tokens", Invidious::Routes::APIv1::Authenticated, :get_tokens
  Invidious::Routing.post "#{{{base_url}}}/auth/tokens/register", Invidious::Routes::APIv1::Authenticated, :register_token
  Invidious::Routing.post "#{{{base_url}}}/auth/tokens/unregister", Invidious::Routes::APIv1::Authenticated, :unregister_token

  # Misc
  Invidious::Routing.get "#{{{base_url}}}/stats", Invidious::Routes::APIv1::Misc, :stats
  Invidious::Routing.get "#{{{base_url}}}/playlists/:plid", Invidious::Routes::APIv1::Misc, :get_playlist
  Invidious::Routing.get "#{{{base_url}}}/auth/playlists/:plid", Invidious::Routes::APIv1::Misc, :get_playlist
  Invidious::Routing.get "#{{{base_url}}}//mixes/:rdid", Invidious::Routes::APIv1::Misc, :mixes

end
