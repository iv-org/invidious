# There is far too many API routes to define in invidious.cr
# so we'll just do it here instead with a macro.
macro define_v1_api_routes(base_url = "/api/v1")
  Invidious::Routing.get "#{{{base_url}}}/stats", Invidious::Routes::V1Api, :stats

  Invidious::Routing.get "#{{{base_url}}}/storyboards/:id", Invidious::Routes::V1Api, :storyboards
  Invidious::Routing.get "#{{{base_url}}}/captions/:id", Invidious::Routes::V1Api, :captions
  Invidious::Routing.get "#{{{base_url}}}/annotations/:id", Invidious::Routes::V1Api, :annotations
  Invidious::Routing.get "#{{{base_url}}}/search/suggestions/:id", Invidious::Routes::V1Api, :search_suggestions

  Invidious::Routing.get "#{{{base_url}}}/comments/:id", Invidious::Routes::V1Api, :comments
  Invidious::Routing.get "#{{{base_url}}}/trending", Invidious::Routes::V1Api, :trending
  Invidious::Routing.get "#{{{base_url}}}/popular", Invidious::Routes::V1Api, :popular

  Invidious::Routing.get "#{{{base_url}}}/channels/:ucid", Invidious::Routes::V1Api, :home

  {% for route in {
                    {"home", "home"},
                    {"videos", "videos"},
                    {"latest", "latest"},
                    {"playlists", "playlists"},
                    {"comments", "community"}, # Why is the route for the community API `comments`?,
                    {"search", "channel_search"},
                  } %}

  Invidious::Routing.get "#{{{base_url}}}/channels/#{{{route[0]}}}/:ucid", Invidious::Routes::V1Api, :{{route[1]}}
  Invidious::Routing.get "#{{{base_url}}}/channels/:ucid/#{{{route[0]}}}", Invidious::Routes::V1Api, :{{route[1]}}

  {% end %}
end
