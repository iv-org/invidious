#
# This file contains youtube API wrappers
#

# Hard-coded constants required by the API
HARDCODED_ANDROID_API_KEY     = "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w"
HARDCODED_ANDROID_CLIENT_VERS = "16.20.35"
HARDCODED_WEB_API_KEY         = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
HARDCODED_WEB_CLIENT_VERS     = "2.20210623.03.00"

####################################################################
# make_youtube_api_context(region)
#
# Return, as a Hash, the "context" data required to request the
# youtube API endpoints.
#
def make_youtube_api_context(region : String | Nil, client_name : String = "WEB") : Hash
  case client_name
  when "ANDROID"
    hardcoded_client_vers = HARDCODED_ANDROID_CLIENT_VERS
  when "WEB"
    hardcoded_client_vers = HARDCODED_WEB_CLIENT_VERS
  else
    hardcoded_client_vers = HARDCODED_WEB_CLIENT_VERS
  end
  return {
    "client" => {
      "hl"            => "en",
      "gl"            => region || "US",       # Can't be empty!
      "clientName"    => client_name || "WEB", # Can't be empty!
      "clientVersion" => hardcoded_client_vers,
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
def request_youtube_api_browse(continuation : String, client_name : String | Nil = "WEB") : Hash(String, JSON::Any)
  # JSON Request data, required by the API
  data = {
    "context"      => make_youtube_api_context("US", client_name),
    "continuation" => continuation,
  }

  return _youtube_api_post_json("/youtubei/v1/browse", data, client_name)
end

def request_youtube_api_browse(browse_id : String, params : String, region : String = "US", client_name : String | Nil = "WEB") : Hash(String, JSON::Any)
  # JSON Request data, required by the API
  data = {
    "browseId" => browse_id,
    "context"  => make_youtube_api_context(region, client_name),
  }

  # Append the additionnal parameters if those were provided
  # (this is required for channel info, playlist and community, e.g)
  if params != ""
    data["params"] = params
  end

  return _youtube_api_post_json("/youtubei/v1/browse", data, client_name)
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
                             client_name : String | Nil = "WEB") : Hash(String, JSON::Any)
  # JSON Request data, required by the API
  data = {
    "context"      => make_youtube_api_context(region, client_name),
    "continuation" => continuation,
  }

  return _youtube_api_post_json("/youtubei/v1/next", data, client_name)
end

def request_youtube_api_next(video_id : String, params : String, region : String | Nil,
                             client_name : String | Nil = "WEB") : Hash(String, JSON::Any)
  # JSON Request data, required by the API
  data = {
    "videoId" => video_id,
    "context" => make_youtube_api_context(region, client_name),
  }

  # Append the additionnal parameters if those were provided
  if params != ""
    data["params"] = params
  end

  return _youtube_api_post_json("/youtubei/v1/next", data, client_name)
end

####################################################################
# request_youtube_api_player(video_id, params)

def request_youtube_api_player(video_id : String, params : String, client_name : String | Nil = "WEB",
                               proxy_region : String | Nil = nil) : Hash(String, JSON::Any)
  # JSON Request data, required by the API
  data = {
    "videoId" => video_id,
    "context" => make_youtube_api_context(proxy_region || "US", client_name),
  }

  # Append the additionnal parameters if those were provided
  if params != ""
    data["params"] = params
  end

  return _youtube_api_post_json("/youtubei/v1/player", data, client_name, proxy_region)
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
                               client_name : String | Nil = "WEB") : Hash(String, JSON::Any)
  # JSON Request data, required by the API
  data = {
    "query"   => search_query,
    "context" => make_youtube_api_context(region, client_name),
    "params"  => params,
  }

  return _youtube_api_post_json("/youtubei/v1/search", data, client_name)
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
def _youtube_api_post_json(endpoint, data, client_name : String | Nil = "WEB",
                           proxy_region : String | Nil = nil) : Hash(String, JSON::Any)
  case client_name
  when "ANDROID"
    hardcoded_api_key = HARDCODED_ANDROID_API_KEY
  when "WEB"
    hardcoded_api_key = HARDCODED_WEB_API_KEY
  else
    hardcoded_api_key = HARDCODED_WEB_API_KEY
  end

  # Send the POST request and parse result
  if proxy_region
    response = YT_POOL.client(proxy_region, &.post(
      "#{endpoint}?key=#{hardcoded_api_key}",
      headers: HTTP::Headers{"content-type" => "application/json; charset=UTF-8"},
      body: data.to_json
    ))
  else
    LOGGER.debug("Using this endpoint for innertube: #{endpoint}")
    LOGGER.debug("Sending this data without proxy\n: #{data.to_s}")
    response = YT_POOL.client &.post(
      "#{endpoint}?key=#{hardcoded_api_key}",
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
