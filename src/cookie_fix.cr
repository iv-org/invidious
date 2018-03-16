# See https://github.com/crystal-lang/crystal/pull/5408
module HTTP
  class Cookie
    module Parser
      SetCookieStringFix = /^#{Regex::CookiePair}(?:;\s*#{Regex::CookieAV})*$/

      def parse_set_cookie(header)
        match = header.match(SetCookieStringFix)
        return unless match

        expires = if max_age = match["max_age"]?
                    Time.now + max_age.to_i.seconds
                  else
                    parse_time(match["expires"]?)
                  end

        Cookie.new(
          match["name"], match["value"],
          path: match["path"]? || "/",
          expires: expires,
          domain: match["domain"]?,
          secure: match["secure"]? != nil,
          http_only: match["http_only"]? != nil,
          extension: match["extension"]?
        )
      end
    end
  end
end
