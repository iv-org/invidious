#
# This file contains youtube API wrappers
#

# Hard-coded constants required by the API
HARDCODED_API_KEY     = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
HARDCODED_CLIENT_VERS = "2.20210330.08.00"

####################################################################
# request_youtube_api_browse(continuation)
#
# Requests the youtubei/vi/browse endpoint with the required headers
# to get JSON in en-US (english US).
#
# The requested data is a continuation token (ctoken). Depending on
# this token's contents, the returned data can be comments, playlist
# videos, search results, channel community tab, ...
#
def request_youtube_api_browse(continuation)
  # JSON Request data, required by the API
  data = {
    "context": {
      "client": {
        "hl":            "en",
        "gl":            "US",
        "clientName":    "WEB",
        "clientVersion": HARDCODED_CLIENT_VERS,
      },
    },
    "continuation": continuation,
  }

  # Send the POST request and parse result
  response = YT_POOL.client &.post(
    "/youtubei/v1/browse?key=#{HARDCODED_API_KEY}",
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
