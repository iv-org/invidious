# Common requires for Invidious
# This file contains the require statements organized by category

# Core requires
require "./config"
require "./exceptions"
require "./hashtag"
require "./mixes"
require "./playlists"
require "./routing"
require "./trending"
require "./users"
require "./videos"

# Jobs (only if not in API-only mode)
{% unless flag?(:api_only) %}
  require "./jobs"
{% end %}