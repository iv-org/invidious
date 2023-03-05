module Invidious::MediaProxy
  extend self

  # -------------------
  #  Constants
  # -------------------

  private REQUEST_HEADERS_WHITELIST = {
    "accept", "accept-encoding", "cache-control",
    "content-length", "if-none-match", "range",
  }

  private RESPONSE_HEADERS_BLACKLIST = {
    "access-control-allow-origin", "alt-svc", "server",
  }

  # -------------------
  #  Headers functions
  # -------------------

  # Copy only the selected headers from the client to youtube servers
  # (in general, from `env.request` to a temporary `HTTP::Headers` object).
  def copy_request_headers(*, from : HTTP::Headers, to : HTTP::Headers)
    REQUEST_HEADERS_WHITELIST.each do |header|
      to[header] = from[header] if from[header]?
    end
  end

  # Copy only the selected headers from youtube servers to the client
  # (generally, from a response block to `env.response`).
  def copy_response_headers(*, from : HTTP::Headers, to : HTTP::Headers)
    from.each do |key, value|
      if !RESPONSE_HEADERS_BLACKLIST.includes?(key.downcase)
        to[key] = value
      end
    end
  end

  # -------------------
  #  Proxy functions
  # -------------------

  def proxy_dash_chunk(
    env : HTTP::Server::Context,
    client : HTTP::Client,
    url : URI | String,
    region : String?
  )
    headers = HTTP::Headers.new
    self.copy_request_headers(from: env.request.headers, to: headers)

    # Make sure to remove a potential range header, to avoid throttling
    headers.delete("Range")

    client.get(url, headers) do |resp|
      env.response.status_code = resp.status_code

      self.copy_response_headers(from: resp.headers, to: env.response.headers)
      env.response.headers["Access-Control-Allow-Origin"] = "*"

      if location = resp.headers["Location"]?
        url = HttpServer::Utils.proxy_video_url(location, region: region)
        env.redirect url
      else
        IO.copy(resp.body_io, env.response)
      end
    end
  rescue ex
  end
end
