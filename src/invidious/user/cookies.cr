require "http/cookie"

struct Invidious::User
  module Cookies
    extend self

    # Note: we use ternary operator because the two variables
    # used in here are not booleans.
    SECURE = (Kemal.config.ssl || CONFIG.https_only) ? true : false

    def domain_for_request(env) : String?
      return domain_for_host(env.request.headers["X-Forwarded-Host"]? || env.request.headers["Host"]?)
    end

    def domain_for_host(request_host : String?) : String?
      configured_domain = CONFIG.domain

      return nil if configured_domain.nil?
      return configured_domain if request_host.nil? || request_host.empty?

      normalized_config = configured_domain.lchop(".").rchop(".").downcase
      normalized_host = normalize_host(request_host)

      if normalized_host == normalized_config || normalized_host.ends_with?(".#{normalized_config}")
        return configured_domain
      end

      return nil
    end

    private def normalize_host(request_host : String) : String
      host = request_host.split(",").first.strip.downcase

      if host.starts_with?("[")
        if bracket_index = host.index(']')
          host = host[1, bracket_index - 1]
        end
      elsif colon_index = host.index(':')
        host = host[0, colon_index]
      end

      return host.rchop(".")
    end

    # Session ID (SID) cookie
    # Parameter "domain" comes from the global config
    def sid(domain : String?, sid) : HTTP::Cookie
      return HTTP::Cookie.new(
        name: "SID",
        domain: domain,
        value: sid,
        expires: Time.utc + 2.years,
        secure: SECURE,
        http_only: true,
        samesite: HTTP::Cookie::SameSite::Lax
      )
    end

    # Preferences (PREFS) cookie
    # Parameter "domain" comes from the global config
    def prefs(domain : String?, preferences : Preferences) : HTTP::Cookie
      return HTTP::Cookie.new(
        name: "PREFS",
        domain: domain,
        value: URI.encode_www_form(preferences.to_json),
        expires: Time.utc + 2.years,
        secure: SECURE,
        http_only: false,
        samesite: HTTP::Cookie::SameSite::Lax
      )
    end
  end
end
