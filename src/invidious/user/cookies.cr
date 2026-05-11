require "http/cookie"

struct Invidious::User
  module Cookies
    extend self

    # Note: we use ternary operator because the two variables
    # used in here are not booleans.
    SECURE = (Kemal.config.ssl || CONFIG.https_only) ? true : false

    # Session ID (SID) cookie
    # Parameter "domain" comes from the global config
    def sid(domain : String?, sid) : HTTP::Cookie
      return HTTP::Cookie.new(
        name: "SID",
        domain: domain,
        path: "/",
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
        path: "/",
        value: URI.encode_www_form(preferences.to_json),
        expires: Time.utc + 2.years,
        secure: SECURE,
        http_only: false,
        samesite: HTTP::Cookie::SameSite::Lax
      )
    end

    def clear_sid(domain : String?) : HTTP::Cookie
      clear("SID", domain, http_only: true)
    end

    def clear_prefs(domain : String?) : HTTP::Cookie
      clear("PREFS", domain, http_only: false)
    end

    private def clear(name : String, domain : String?, http_only : Bool) : HTTP::Cookie
      return HTTP::Cookie.new(
        name: name,
        domain: domain,
        path: "/",
        value: "",
        expires: Time.utc(1990, 1, 1),
        secure: SECURE,
        http_only: http_only,
        samesite: HTTP::Cookie::SameSite::Lax
      )
    end
  end
end
