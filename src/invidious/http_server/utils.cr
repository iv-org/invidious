module Invidious::HttpServer
  module Utils
    extend self

    def proxy_video_url(raw_url : String, *, region : String? = nil, absolute : Bool = false)
      url = URI.parse(raw_url)

      # Add some URL parameters
      params = url.query_params
      params["host"] = url.host.not_nil! # Should never be nil, in theory
      params["region"] = region if !region.nil?

      if absolute
        return "#{HOST_URL}#{url.request_target}?#{params}"
      else
        return "#{url.request_target}?#{params}"
      end
    end
  end
end
