#
# This file contains youtube API wrappers
#

module YoutubeAPI
  extend self

  private DEFAULT_API_KEY = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"

  private ANDROID_APP_VERSION = "18.20.38"
  # github.com/TeamNewPipe/NewPipeExtractor/blob/943b7c033bb9d07ead63ddab4441c287653e4384/extractor/src/main/java/org/schabi/newpipe/extractor/services/youtube/YoutubeParsingHelper.java#L1308
  private ANDROID_USER_AGENT  = "com.google.android.youtube/18.20.38 (Linux; U; Android 12; US) gzip"
  private ANDROID_SDK_VERSION = 31_i64
  private ANDROID_VERSION     = "12"

  private IOS_APP_VERSION = "18.21.3"
  # github.com/TeamNewPipe/NewPipeExtractor/blob/943b7c033bb9d07ead63ddab4441c287653e4384/extractor/src/main/java/org/schabi/newpipe/extractor/services/youtube/YoutubeParsingHelper.java#L1330
  private IOS_USER_AGENT = "com.google.ios.youtube/18.21.3 (iPhone14,5; U; CPU iOS 15_6 like Mac OS X;)"
  # github.com/TeamNewPipe/NewPipeExtractor/blob/943b7c033bb9d07ead63ddab4441c287653e4384/extractor/src/main/java/org/schabi/newpipe/extractor/services/youtube/YoutubeParsingHelper.java#L1224
  private IOS_VERSION = "15.6.0.19G71"

  private WINDOWS_VERSION = "10.0"

  # Enumerate used to select one of the clients supported by the API
  enum ClientType
    Web
    WebEmbeddedPlayer
    WebMobile
    WebScreenEmbed

    Android
    AndroidEmbeddedPlayer
    AndroidScreenEmbed

    IOS
    IOSEmbedded
    IOSMusic

    TvHtml5
    TvHtml5ScreenEmbed
  end

  # List of hard-coded values used by the different clients
  HARDCODED_CLIENTS = {
    ClientType::Web => {
      name:       "WEB",
      name_proto: "1",
      version:    "2.20230602.01.00",
      api_key:    DEFAULT_API_KEY,
      screen:     "WATCH_FULL_SCREEN",
      os_name:    "Windows",
      os_version: WINDOWS_VERSION,
      platform:   "DESKTOP",
    },
    ClientType::WebEmbeddedPlayer => {
      name:       "WEB_EMBEDDED_PLAYER",
      name_proto: "56",
      version:    "1.20220803.01.00",
      api_key:    DEFAULT_API_KEY,
      screen:     "EMBED",
      os_name:    "Windows",
      os_version: WINDOWS_VERSION,
      platform:   "DESKTOP",
    },
    ClientType::WebMobile => {
      name:       "MWEB",
      name_proto: "2",
      version:    "2.20230531.05.00",
      api_key:    DEFAULT_API_KEY,
      os_name:    "Android",
      os_version: ANDROID_VERSION,
      platform:   "MOBILE",
    },
    ClientType::WebScreenEmbed => {
      name:       "WEB",
      name_proto: "1",
      version:    "2.20220804.00.00",
      api_key:    DEFAULT_API_KEY,
      screen:     "EMBED",
      os_name:    "Windows",
      os_version: WINDOWS_VERSION,
      platform:   "DESKTOP",
    },

    # Android

    ClientType::Android => {
      name:                "ANDROID",
      name_proto:          "3",
      version:             ANDROID_APP_VERSION,
      api_key:             "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w",
      android_sdk_version: ANDROID_SDK_VERSION,
      user_agent:          ANDROID_USER_AGENT,
      os_name:             "Android",
      os_version:          ANDROID_VERSION,
      platform:            "MOBILE",
    },
    ClientType::AndroidEmbeddedPlayer => {
      name:       "ANDROID_EMBEDDED_PLAYER",
      name_proto: "55",
      version:    ANDROID_APP_VERSION,
      api_key:    DEFAULT_API_KEY,
    },
    ClientType::AndroidScreenEmbed => {
      name:                "ANDROID",
      name_proto:          "3",
      version:             ANDROID_APP_VERSION,
      api_key:             DEFAULT_API_KEY,
      screen:              "EMBED",
      android_sdk_version: ANDROID_SDK_VERSION,
      user_agent:          ANDROID_USER_AGENT,
      os_name:             "Android",
      os_version:          ANDROID_VERSION,
      platform:            "MOBILE",
    },

    # IOS

    ClientType::IOS => {
      name:         "IOS",
      name_proto:   "5",
      version:      IOS_APP_VERSION,
      api_key:      "AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc",
      user_agent:   IOS_USER_AGENT,
      device_make:  "Apple",
      device_model: "iPhone14,5",
      os_name:      "iPhone",
      os_version:   IOS_VERSION,
      platform:     "MOBILE",
    },
    ClientType::IOSEmbedded => {
      name:         "IOS_MESSAGES_EXTENSION",
      name_proto:   "66",
      version:      IOS_APP_VERSION,
      api_key:      DEFAULT_API_KEY,
      user_agent:   IOS_USER_AGENT,
      device_make:  "Apple",
      device_model: "iPhone14,5",
      os_name:      "iPhone",
      os_version:   IOS_VERSION,
      platform:     "MOBILE",
    },
    ClientType::IOSMusic => {
      name:         "IOS_MUSIC",
      name_proto:   "26",
      version:      "5.21",
      api_key:      "AIzaSyBAETezhkwP0ZWA02RsqT1zu78Fpt0bC_s",
      user_agent:   "com.google.ios.youtubemusic/5.21 (iPhone14,5; U; CPU iOS 15_6 like Mac OS X;)",
      device_make:  "Apple",
      device_model: "iPhone14,5",
      os_name:      "iPhone",
      os_version:   IOS_VERSION,
      platform:     "MOBILE",
    },

    # TV app

    ClientType::TvHtml5 => {
      name:       "TVHTML5",
      name_proto: "7",
      version:    "7.20220325",
      api_key:    DEFAULT_API_KEY,
    },
    ClientType::TvHtml5ScreenEmbed => {
      name:       "TVHTML5_SIMPLY_EMBEDDED_PLAYER",
      name_proto: "85",
      version:    "2.0",
      api_key:    DEFAULT_API_KEY,
      screen:     "EMBED",
    },
  }

  ####################################################################
  # struct ClientConfig
  #
  # Data structure used to pass a client configuration to the different
  # API endpoints handlers.
  #
  # Use case examples:
  #
  # ```
  # # Get Norwegian search results
  # conf_1 = ClientConfig.new(region: "NO")
  # YoutubeAPI::search("Kollektivet", params: "", client_config: conf_1)
  #
  # # Use the Android client to request video streams URLs
  # conf_2 = ClientConfig.new(client_type: ClientType::Android)
  # YoutubeAPI::player(video_id: "dQw4w9WgXcQ", client_config: conf_2)
  #
  # # Proxy request through russian proxies
  # conf_3 = ClientConfig.new(proxy_region: "RU")
  # YoutubeAPI::next({video_id: "dQw4w9WgXcQ"}, client_config: conf_3)
  # ```
  #
  struct ClientConfig
    # Type of client to emulate.
    # See `enum ClientType` and `HARDCODED_CLIENTS`.
    property client_type : ClientType

    # Region to provide to youtube, e.g to alter search results
    # (this is passed as the `gl` parameter).
    property region : String | Nil

    # ISO code of country where the proxy is located.
    # Used in case of geo-restricted videos.
    property proxy_region : String | Nil

    # Initialization function
    def initialize(
      *,
      @client_type = ClientType::Web,
      @region = "US",
      @proxy_region = nil
    )
    end

    # Getter functions that provides easy access to hardcoded clients
    # parameters (name/version strings and related API key)
    def name : String
      HARDCODED_CLIENTS[@client_type][:name]
    end

    def name_proto : String
      HARDCODED_CLIENTS[@client_type][:name_proto]
    end

    # :ditto:
    def version : String
      HARDCODED_CLIENTS[@client_type][:version]
    end

    # :ditto:
    def api_key : String
      HARDCODED_CLIENTS[@client_type][:api_key]
    end

    # :ditto:
    def screen : String
      HARDCODED_CLIENTS[@client_type][:screen]? || ""
    end

    def android_sdk_version : Int64?
      HARDCODED_CLIENTS[@client_type][:android_sdk_version]?
    end

    def user_agent : String?
      HARDCODED_CLIENTS[@client_type][:user_agent]?
    end

    def os_name : String?
      HARDCODED_CLIENTS[@client_type][:os_name]?
    end

    def device_make : String?
      HARDCODED_CLIENTS[@client_type][:device_make]?
    end

    def device_model : String?
      HARDCODED_CLIENTS[@client_type][:device_model]?
    end

    def os_version : String?
      HARDCODED_CLIENTS[@client_type][:os_version]?
    end

    def platform : String?
      HARDCODED_CLIENTS[@client_type][:platform]?
    end

    # Convert to string, for logging purposes
    def to_s
      return {
        client_type:  self.name,
        region:       @region,
        proxy_region: @proxy_region,
      }.to_s
    end
  end

  # Default client config, used if nothing is passed
  DEFAULT_CLIENT_CONFIG = ClientConfig.new

  ####################################################################
  # make_context(client_config)
  #
  # Return, as a Hash, the "context" data required to request the
  # youtube API endpoints.
  #
  private def make_context(client_config : ClientConfig | Nil) : Hash
    # Use the default client config if nil is passed
    client_config ||= DEFAULT_CLIENT_CONFIG

    client_context = {
      "client" => {
        "hl"            => "en",
        "gl"            => client_config.region || "US", # Can't be empty!
        "clientName"    => client_config.name,
        "clientVersion" => client_config.version,
      } of String => String | Int64,
    }

    # Add some more context if it exists in the client definitions
    if !client_config.screen.empty?
      client_context["client"]["clientScreen"] = client_config.screen
    end

    if client_config.screen == "EMBED"
      client_context["thirdParty"] = {
        "embedUrl" => "https://www.youtube.com/embed/dQw4w9WgXcQ",
      } of String => String | Int64
    end

    if android_sdk_version = client_config.android_sdk_version
      client_context["client"]["androidSdkVersion"] = android_sdk_version
    end

    if device_make = client_config.device_make
      client_context["client"]["deviceMake"] = device_make
    end

    if device_model = client_config.device_model
      client_context["client"]["deviceModel"] = device_model
    end

    if os_name = client_config.os_name
      client_context["client"]["osName"] = os_name
    end

    if os_version = client_config.os_version
      client_context["client"]["osVersion"] = os_version
    end

    if platform = client_config.platform
      client_context["client"]["platform"] = platform
    end

    return client_context
  end

  ####################################################################
  # browse(continuation, client_config?)
  # browse(browse_id, params, client_config?)
  #
  # Requests the youtubei/v1/browse endpoint with the required headers
  # and POST data in order to get a JSON reply in english that can
  # be easily parsed.
  #
  # Both forms can take an optional ClientConfig parameter (see
  # `struct ClientConfig` above for more details).
  #
  # The requested data can either be:
  #
  #  - A continuation token (ctoken). Depending on this token's
  #    contents, the returned data can be playlist videos, channel
  #    community tab content, channel info, ...
  #
  #  - A playlist ID (parameters MUST be an empty string)
  #
  def browse(continuation : String, client_config : ClientConfig | Nil = nil)
    # JSON Request data, required by the API
    data = {
      "context"      => self.make_context(client_config),
      "continuation" => continuation,
    }

    return self._post_json("/youtubei/v1/browse", data, client_config)
  end

  # :ditto:
  def browse(
    browse_id : String,
    *, # Force the following parameters to be passed by name
    params : String,
    client_config : ClientConfig | Nil = nil
  )
    # JSON Request data, required by the API
    data = {
      "browseId" => browse_id,
      "context"  => self.make_context(client_config),
    }

    # Append the additional parameters if those were provided
    # (this is required for channel info, playlist and community, e.g)
    if params != ""
      data["params"] = params
    end

    return self._post_json("/youtubei/v1/browse", data, client_config)
  end

  ####################################################################
  # next(continuation, client_config?)
  # next(data, client_config?)
  #
  # Requests the youtubei/v1/next endpoint with the required headers
  # and POST data in order to get a JSON reply in english that can
  # be easily parsed.
  #
  # Both forms can take an optional ClientConfig parameter (see
  # `struct ClientConfig` above for more details).
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
  def next(continuation : String, *, client_config : ClientConfig | Nil = nil)
    # JSON Request data, required by the API
    data = {
      "context"      => self.make_context(client_config),
      "continuation" => continuation,
    }

    return self._post_json("/youtubei/v1/next", data, client_config)
  end

  # :ditto:
  def next(data : Hash, *, client_config : ClientConfig | Nil = nil)
    # JSON Request data, required by the API
    data2 = data.merge({
      "context" => self.make_context(client_config),
    })

    return self._post_json("/youtubei/v1/next", data2, client_config)
  end

  # Allow a NamedTuple to be passed, too.
  def next(data : NamedTuple, *, client_config : ClientConfig | Nil = nil)
    return self.next(data.to_h, client_config: client_config)
  end

  ####################################################################
  # player(video_id, params, client_config?)
  #
  # Requests the youtubei/v1/player endpoint with the required headers
  # and POST data in order to get a JSON reply.
  #
  # The requested data is a video ID (`v=` parameter), with some
  # additional parameters, formatted as a base64 string.
  #
  # An optional ClientConfig parameter can be passed, too (see
  # `struct ClientConfig` above for more details).
  #
  def player(
    video_id : String,
    *, # Force the following parameters to be passed by name
    params : String,
    client_config : ClientConfig | Nil = nil
  )
    # JSON Request data, required by the API
    data = {
      "contentCheckOk" => true,
      "videoId"        => video_id,
      "context"        => self.make_context(client_config),
      "racyCheckOk"    => true,
      "user"           => {
        "lockedSafetyMode" => false,
      },
      "playbackContext" => {
        "contentPlaybackContext" => {
          "html5Preference": "HTML5_PREF_WANTS",
        },
      },
    }

    # Append the additional parameters if those were provided
    if params != ""
      data["params"] = params
    end

    return self._post_json("/youtubei/v1/player", data, client_config)
  end

  ####################################################################
  # resolve_url(url, client_config?)
  #
  # Requests the youtubei/v1/navigation/resolve_url endpoint with the
  # required headers and POST data in order to get a JSON reply.
  #
  # An optional ClientConfig parameter can be passed, too (see
  # `struct ClientConfig` above for more details).
  #
  # Output:
  #
  # ```
  # # Valid channel "brand URL" gives the related UCID and browse ID
  # channel_a = YoutubeAPI.resolve_url("https://youtube.com/c/google")
  # channel_a # => {
  #   "endpoint": {
  #     "browseEndpoint": {
  #       "params": "EgC4AQA%3D",
  #       "browseId":"UCK8sQmJBp8GCxrOtXWBpyEA"
  #     },
  #     ...
  #   }
  # }
  #
  # # Invalid URL returns throws an InfoException
  # channel_b = YoutubeAPI.resolve_url("https://youtube.com/c/invalid")
  # ```
  #
  def resolve_url(url : String, client_config : ClientConfig | Nil = nil)
    data = {
      "context" => self.make_context(nil),
      "url"     => url,
    }

    return self._post_json("/youtubei/v1/navigation/resolve_url", data, client_config)
  end

  ####################################################################
  # search(search_query, params, client_config?)
  #
  # Requests the youtubei/v1/search endpoint with the required headers
  # and POST data in order to get a JSON reply. As the search results
  # vary depending on the region, a region code can be specified in
  # order to get non-US results.
  #
  # The requested data is a search string, with some additional
  # parameters, formatted as a base64 string.
  #
  # An optional ClientConfig parameter can be passed, too (see
  # `struct ClientConfig` above for more details).
  #
  def search(
    search_query : String,
    params : String,
    client_config : ClientConfig | Nil = nil
  )
    # JSON Request data, required by the API
    data = {
      "query"   => search_query,
      "context" => self.make_context(client_config),
      "params"  => params,
    }

    return self._post_json("/youtubei/v1/search", data, client_config)
  end

  ####################################################################
  # _post_json(endpoint, data, client_config?)
  #
  # Internal function that does the actual request to youtube servers
  # and handles errors.
  #
  # The requested data is an endpoint (URL without the domain part)
  # and the data as a Hash object.
  #
  def _post_json(
    endpoint : String,
    data : Hash,
    client_config : ClientConfig | Nil
  ) : Hash(String, JSON::Any)
    # Use the default client config if nil is passed
    client_config ||= DEFAULT_CLIENT_CONFIG

    # Query parameters
    url = "#{endpoint}?key=#{client_config.api_key}&prettyPrint=false"

    headers = HTTP::Headers{
      "Content-Type"              => "application/json; charset=UTF-8",
      "Accept-Encoding"           => "gzip, deflate",
      "x-goog-api-format-version" => "2",
      "x-youtube-client-name"     => client_config.name_proto,
      "x-youtube-client-version"  => client_config.version,
    }

    if user_agent = client_config.user_agent
      headers["User-Agent"] = user_agent
    end

    # Logging
    LOGGER.debug("YoutubeAPI: Using endpoint: \"#{endpoint}\"")
    LOGGER.trace("YoutubeAPI: ClientConfig: #{client_config}")
    LOGGER.trace("YoutubeAPI: POST data: #{data}")

    # Send the POST request
    if {{ !flag?(:disable_quic) }} && CONFIG.use_quic
      # Using QUIC client
      body = YT_POOL.client(client_config.proxy_region,
        &.post(url, headers: headers, body: data.to_json)
      ).body
    else
      # Using HTTP client
      body = YT_POOL.client(client_config.proxy_region) do |client|
        client.post(url, headers: headers, body: data.to_json) do |response|
          self._decompress(response.body_io, response.headers["Content-Encoding"]?)
        end
      end
    end

    # Convert result to Hash
    initial_data = JSON.parse(body).as_h

    # Error handling
    if initial_data.has_key?("error")
      code = initial_data["error"]["code"]
      message = initial_data["error"]["message"].to_s.sub(/(\\n)+\^$/, "")

      # Logging
      LOGGER.error("YoutubeAPI: Got error #{code} when requesting #{endpoint}")
      LOGGER.error("YoutubeAPI: #{message}")
      LOGGER.info("YoutubeAPI: POST data was: #{data}")

      raise InfoException.new("Could not extract JSON. Youtube API returned \
      error #{code} with message:<br>\"#{message}\"")
    end

    return initial_data
  end

  ####################################################################
  # _decompress(body_io, headers)
  #
  # Internal function that reads the Content-Encoding headers and
  # decompresses the content accordingly.
  #
  # We decompress the body ourselves (when using HTTP::Client) because
  # the auto-decompress feature is broken in the Crystal stdlib.
  #
  # Read more:
  #  - https://github.com/iv-org/invidious/issues/2612
  #  - https://github.com/crystal-lang/crystal/issues/11354
  #
  def _decompress(body_io : IO, encodings : String?) : String
    if encodings
      # Multiple encodings can be combined, and are listed in the order
      # in which they were applied. E.g: "deflate, gzip" means that the
      # content must be first "gunzipped", then "defated".
      encodings.split(',').reverse.each do |enc|
        case enc.strip(' ')
        when "gzip"
          body_io = Compress::Gzip::Reader.new(body_io, sync_close: true)
        when "deflate"
          body_io = Compress::Deflate::Reader.new(body_io, sync_close: true)
        end
      end
    end

    return body_io.gets_to_end
  end
end # End of module
