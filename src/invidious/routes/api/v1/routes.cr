# There is far too many API routes to define in invidious.cr
# so we'll just do it here instead with a macro.
macro define_v1_api_routes(base_url = "/api/v1")
  Invidious::Routing.get "#{{{base_url}}}/stats", Invidious::Routes::APIv1::Misc, :stats

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
end
