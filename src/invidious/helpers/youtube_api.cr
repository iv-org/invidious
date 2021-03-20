#
# This file contains youtube API wrappers
#

# Hard-coded constants required by the API
HARDCODED_API_KEY     = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
HARDCODED_CLIENT_VERS = "2.20210318.08.00"

def request_youtube_api_browse(continuation)
  # JSON Request data, required by the API
  data = {
    "context": {
      "client": {
        "hl": "en",
        "gl": "US",
        "clientName": "WEB",
        "clientVersion": HARDCODED_CLIENT_VERS,
      },
    },
    "continuation": continuation,
  }

  # Send the POST request and return result
  response = YT_POOL.client &.post(
    "/youtubei/v1/browse?key=#{HARDCODED_API_KEY}",
    headers: HTTP::Headers{"content-type" => "application/json"},
    body: data.to_json
  )

  return response.body
end
