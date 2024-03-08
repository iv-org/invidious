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
  end
end
