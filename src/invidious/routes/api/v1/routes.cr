# There is far too many API routes to define in invidious.cr
# so we'll just do it here instead with a macro.
macro define_v1_api_routes(base_url = "/api/v1")
  Invidious::Routing.get "#{{{base_url}}}/stats", Invidious::Routes::APIv1, :stats

  # Widgets
  Invidious::Routing.get "#{{{base_url}}}/storyboards/:id", Invidious::Routes::APIv1, :storyboards
  Invidious::Routing.get "#{{{base_url}}}/captions/:id", Invidious::Routes::APIv1, :captions
  Invidious::Routing.get "#{{{base_url}}}/annotations/:id", Invidious::Routes::APIv1, :annotations
  Invidious::Routing.get "#{{{base_url}}}/search/suggestions/:id", Invidious::Routes::APIv1, :search_suggestions
  Invidious::Routing.get "#{{{base_url}}}/comments/:id", Invidious::Routes::APIv1, :comments

  # Feeds
  Invidious::Routing.get "#{{{base_url}}}/trending", Invidious::Routes::APIv1, :trending
  Invidious::Routing.get "#{{{base_url}}}/popular", Invidious::Routes::APIv1, :popular

  # Channels
  Invidious::Routing.get "#{{{base_url}}}/channels/:ucid", Invidious::Routes::APIv1, :home
  {% for route in {
                    {"home", "home"},
                    {"videos", "videos"},
                    {"latest", "latest"},
                    {"playlists", "playlists"},
                    {"comments", "community"}, # Why is the route for the community API `comments`?,
                    {"search", "channel_search"},
                  } %}

  Invidious::Routing.get "#{{{base_url}}}/channels/#{{{route[0]}}}/:ucid", Invidious::Routes::APIv1, :{{route[1]}}
  Invidious::Routing.get "#{{{base_url}}}/channels/:ucid/#{{{route[0]}}}", Invidious::Routes::APIv1, :{{route[1]}}
  {% end %}

  # Search
  Invidious::Routing.get "#{{{base_url}}}/search", Invidious::Routes::APIv1, :search
  Invidious::Routing.get "#{{{base_url}}}/videos/:id", Invidious::Routes::APIv1, :videos
  Invidious::Routing.get "#{{{base_url}}}/search", Invidious::Routes::APIv1, :search

end
