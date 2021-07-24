#
# This file contains youtube API wrappers
#

module YoutubeAPI
  extend self

  # Hard-coded constants required by the API
  HARDCODED_API_KEY     = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
  HARDCODED_CLIENT_VERS = "2.20210330.08.00"

  ####################################################################
  # make_context(region)
  #
  # Return, as a Hash, the "context" data required to request the
  # youtube API endpoints.
  #
  private def make_context(region : String | Nil) : Hash
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
  # browse(continuation)
  # browse(browse_id, params)
  # browse(browse_id, params, region)
  #
  # Requests the youtubei/v1/browse endpoint with the required headers
  # and POST data in order to get a JSON reply in english that can
  # be easily parsed.
  #
  # A region can be provided, default is US.
  #
  # The requested data can either be:
  #
  #  - A continuation token (ctoken). Depending on this token's
  #    contents, the returned data can be comments, playlist videos,
  #    search results, channel community tab, ...
  #
  #  - A playlist ID (parameters MUST be an empty string)
  #
  def browse(continuation : String)
    # JSON Request data, required by the API
    data = {
      "context"      => self.make_context("US"),
      "continuation" => continuation,
    }

    return self._post_json("/youtubei/v1/browse", data)
  end

  # :ditto:
  def browse(browse_id : String, *, params : String, region : String = "US")
    # JSON Request data, required by the API
    data = {
      "browseId" => browse_id,
      "context"  => self.make_context(region),
    }

    # Append the additionnal parameters if those were provided
    # (this is required for channel info, playlist and community, e.g)
    if params != ""
      data["params"] = params
    end

    return self._post_json("/youtubei/v1/browse", data)
  end

  ####################################################################
  # next(continuation)
  # next(continuation, region)
  # next(data)
  # next(data, region)
  #
  # Requests the youtubei/v1/next endpoint with the required headers
  # and POST data in order to get a JSON reply in english that can
  # be easily parsed.
  #
  # The requested data can be:
  #
  #  - A continuation token (ctoken). Depending on this token's
  #    contents, the returned data can be videos comments,
  #    their replies, ... In this case, the string must be passed
  #    directly to the function. E.g:
  #
  #    ```
  #    YoutubeAPI::next("ABCDEFGH_abcdefgh==")
  #    ```
  #
  #  - Arbitrary parameters, in Hash form. See examples below for
  #    known examples of arbitrary data that can be passed to YouTube:
  #
  #    ```
  #    # Get the videos related to a specific video ID
  #    YoutubeAPI::next({"videoId" => "dQw4w9WgXcQ"})
  #
  #    # Get a playlist video's details
  #    YoutubeAPI::next({
  #      "videoId"    => "9bZkp7q19f0",
  #      "playlistId" => "PL_oFlvgqkrjUVQwiiE3F3k3voF4tjXeP0",
  #    })
  #    ```
  #
  # Both forms can take an optional region parameter, that ay
  # impact the data returned by youtube (e.g translation of some
  # video titles). E.g:
  #
  # ```
  # YoutubeAPI::next("ABCDEFGH_abcdefgh==", region: "FR")
  # YoutubeAPI::next({"videoId": "dQw4w9WgXcQ"}, region: "DE")
  # ```
  #
  def next(continuation : String, *, region : String | Nil = nil)
    # JSON Request data, required by the API
    data = {
      "context"      => self.make_context(region),
      "continuation" => continuation,
    }

    return self._post_json("/youtubei/v1/next", data)
  end

  # :ditto:
  def next(data : Hash, *, region : String | Nil = nil)
    # JSON Request data, required by the API
    data.merge!({
      "context" => self.make_context(region),
    })

    return self._post_json("/youtubei/v1/next", data)
  end

  # Allow a NamedTuple to be passed, too.
  def next(data : NamedTuple, *, region : String | Nil = nil)
    return self.next(data.to_h, region: region)
  end

  ####################################################################
  # search(search_query, params, region)
  #
  # Requests the youtubei/v1/search endpoint with the required headers
  # and POST data in order to get a JSON reply. As the search results
  # vary depending on the region, a region code can be specified in
  # order to get non-US results.
  #
  # The requested data is a search string, with some additional
  # paramters, formatted as a base64 string.
  #
  def search(search_query : String, params : String, region = nil)
    # JSON Request data, required by the API
    data = {
      "query"   => search_query,
      "context" => self.make_context(region),
      "params"  => params,
    }

    return self._post_json("/youtubei/v1/search", data)
  end

  ####################################################################
  # _post_json(endpoint, data)
  #
  # Internal function that does the actual request to youtube servers
  # and handles errors.
  #
  # The requested data is an endpoint (URL without the domain part)
  # and the data as a Hash object.
  #
  def _post_json(endpoint, data) : Hash(String, JSON::Any)
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
end # End of module
