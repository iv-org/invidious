#
# This file contains youtube API wrappers
#

# Hard-coded constants required by the API
enum ApiClients
  Web     = 0
  Android = 1
end

HARDCODED_CLIENTS = {
  ApiClients::Web => {name: "WEB", version: "2.20210623.03.00",
                      key: "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"},
  ApiClients::Android => {name: "ANDROID", version: "16.20.35",
                          key: "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w"},
}

####################################################################
# make_youtube_api_context(region)
#
# Return, as a Hash, the "context" data required to request the
# youtube API endpoints.
#
def make_youtube_api_context(region : String | Nil, client_type = ApiClients::Web) : Hash
  client_infos = HARDCODED_CLIENTS[client_type]
  client_version = client_infos["version"]
  client_name = client_infos["name"]
  default_client_infos = HARDCODED_CLIENTS[ApiClients::Web]
  default_client_version = default_client_infos["version"]
  default_client_name = default_client_infos["version"]
  return {
    "client" => {
      "hl"            => "en",
      "gl"            => region || "US",                           # Can't be empty!
      "clientName"    => client_name || default_client_name,       # Can't be empty!
      "clientVersion" => client_version || default_client_version, # Can't be empty!
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
def request_youtube_api_browse(continuation : String, client_type = ApiClients::Web) : Hash(String, JSON::Any)
  # JSON Request data, required by the API
  data = {
    "context"      => make_youtube_api_context("US", client_type),
    "continuation" => continuation,
  }

  return _youtube_api_post_json("/youtubei/v1/browse", data, client_type)
end

def request_youtube_api_browse(browse_id : String, params : String, region : String = "US", client_type = ApiClients::Web) : Hash(String, JSON::Any)
  # JSON Request data, required by the API
  data = {
    "browseId" => browse_id,
    "context"  => make_youtube_api_context(region, client_type),
  }

  # Append the additionnal parameters if those were provided
  # (this is required for channel info, playlist and community, e.g)
  if params != ""
    data["params"] = params
  end

  return _youtube_api_post_json("/youtubei/v1/browse", data, client_type)
end

####################################################################
# request_youtube_api_next(continuation)
# request_youtube_api_next(video_id, params)
#
# Requests the youtubei/v1/next endpoint with the required headers
# and POST data in order to get a JSON reply in english that can
# be easily parsed.
#
# The requested data can either be:
#
#  - A continuation token (ctoken). Depending on this token's
#    contents, the returned data can be comments, playlist videos,
#    search results, channel community tab, ...
#
#  - A video ID (parameters MUST be an empty string)
#

def request_youtube_api_next(continuation : String, region : String | Nil,
                             client_type = ApiClients::Web) : Hash(String, JSON::Any)
  # JSON Request data, required by the API
  data = {
    "context"      => make_youtube_api_context(region, client_type),
    "continuation" => continuation,
  }

  return _youtube_api_post_json("/youtubei/v1/next", data, client_type)
end

def request_youtube_api_next(video_id : String, params : String, region : String | Nil,
                             client_type = ApiClients::Web) : Hash(String, JSON::Any)
  # JSON Request data, required by the API
  data = {
    "videoId" => video_id,
    "context" => make_youtube_api_context(region, client_type),
  }

  # Append the additionnal parameters if those were provided
  if params != ""
    data["params"] = params
  end

  return _youtube_api_post_json("/youtubei/v1/next", data, client_type)
end

####################################################################
# request_youtube_api_player(video_id, params)

def request_youtube_api_player(video_id : String, params : String, client_type = ApiClients::Web,
                               proxy_region : String | Nil = nil) : Hash(String, JSON::Any)
  # JSON Request data, required by the API
  data = {
    "videoId" => video_id,
    "context" => make_youtube_api_context(proxy_region || "US", client_type),
  }

  # Append the additionnal parameters if those were provided
  if params != ""
    data["params"] = params
  end

  return _youtube_api_post_json("/youtubei/v1/player", data, client_type, proxy_region)
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
def request_youtube_api_search(search_query : String, params : String, region = nil,
                               client_type = ApiClients::Web) : Hash(String, JSON::Any)
  # JSON Request data, required by the API
  data = {
    "query"   => search_query,
    "context" => make_youtube_api_context(region, client_type),
    "params"  => params,
  }

  return _youtube_api_post_json("/youtubei/v1/search", data, client_type)
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
def _youtube_api_post_json(endpoint, data, client_type = ApiClients::Web,
                           proxy_region : String | Nil = nil) : Hash(String, JSON::Any)
  client_key = HARDCODED_CLIENTS[client_type]["key"]
  default_client_key = HARDCODED_CLIENTS[ApiClients::Web]["key"]

  # Send the POST request and parse result
  if proxy_region
    response = YT_POOL.client(proxy_region, &.post(
      "#{endpoint}?key=#{client_key || default_client_key}",
      headers: HTTP::Headers{
        "content-type"  => "application/json; charset=UTF-8",
        "Accept-Encoding": "gzip",
      },
      body: data.to_json
    ))
  else
    LOGGER.debug("Using this endpoint for innertube: #{endpoint}")
    LOGGER.debug("Sending this data without proxy\n: #{data.to_s}")
    response = YT_POOL.client &.post(
      "#{endpoint}?key=#{client_key || default_client_key}",
      headers: HTTP::Headers{
        "content-type"  => "application/json; charset=UTF-8",
        "Accept-Encoding": "gzip",
      },
      body: data.to_json
    )
  end

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
