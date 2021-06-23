#
# This file contains youtube API wrappers
#

# Hard-coded constants required by the API
HARDCODED_API_KEY     = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
HARDCODED_CLIENT_VERS = "2.20210330.08.00"

####################################################################
# make_youtube_api_context(region)
#
# Return, as a Hash, the "context" data required to request the
# youtube API endpoints.
#
def make_youtube_api_context(region : String | Nil) : Hash
  return {
    "client" => {
      "hl"            => "en",
      "gl"            => region || "US", # Can't be empty!
      "clientName"    => "WEB",
      "clientVersion" => HARDCODED_CLIENT_VERS,
    },
  }
end

####################################################################
# request_youtube_api_browse(continuation)
# request_youtube_api_browse(browse_id, params, region)
#
# Requests the youtubei/v1/browse endpoint with the required headers
# and POST data in order to get a JSON reply in english that can
# be easily parsed.
#
# The region can be provided, default is US.
#
# The requested data can either be:
#
#  - A continuation token (ctoken). Depending on this token's
#    contents, the returned data can be comments, playlist videos,
#    search results, channel community tab, ...
#
#  - A playlist ID (parameters MUST be an empty string)
#
def request_youtube_api_browse(continuation : String)
  # JSON Request data, required by the API
  data = {
    "context"      => make_youtube_api_context("US"),
    "continuation" => continuation,
  }

  return _youtube_api_post_json("/youtubei/v1/browse", data)
end

def request_youtube_api_browse(browse_id : String, params : String, region : String = "US")
  # JSON Request data, required by the API
  data = {
    "browseId" => browse_id,
    "context"  => make_youtube_api_context(region),
  }

  # Append the additionnal parameters if those were provided
  # (this is required for channel info, playlist and community, e.g)
  if params != ""
    data["params"] = params
  end

  return _youtube_api_post_json("/youtubei/v1/browse", data)
end

####################################################################
# request_youtube_api_search(search_query, params, region)
#
# Requests the youtubei/v1/search endpoint with the required headers
# and POST data in order to get a JSON reply. As the search results
# vary depending on the region, a region code can be specified in
# order to get non-US results.
#
# The requested data is a search string, with some additional
# paramters, formatted as a base64 string.
#
def request_youtube_api_search(search_query : String, params : String, region = nil)
  # JSON Request data, required by the API
  data = {
    "query"   => search_query,
    "context" => make_youtube_api_context(region),
    "params"  => params,
  }

  return _youtube_api_post_json("/youtubei/v1/search", data)
end

####################################################################
# _youtube_api_post_json(endpoint, data)
#
# Internal function that does the actual request to youtube servers
# and handles errors.
#
# The requested data is an endpoint (URL without the domain part)
# and the data as a Hash object.
#
def _youtube_api_post_json(endpoint, data)
  # Send the POST request and parse result
  response = YT_POOL.client &.post(
    "#{endpoint}?key=#{HARDCODED_API_KEY}",
    headers: HTTP::Headers{"content-type" => "application/json; charset=UTF-8"},
    body: data.to_json
  )

  initial_data = JSON.parse(response.body).as_h

  # Error handling
  if initial_data.has_key?("error")
    code = initial_data["error"]["code"]
    message = initial_data["error"]["message"].to_s.sub(/(\\n)+\^$/, "")

    raise InfoException.new("Could not extract JSON. Youtube API returned \
      error #{code} with message:<br>\"#{message}\"")
  end

  return initial_data
end
