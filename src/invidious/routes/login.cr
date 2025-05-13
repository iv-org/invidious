{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Login
  def self.login_page(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"

    referer = get_referer(env, "/feed/subscriptions")

    return env.redirect referer if user

    if !CONFIG.login_enabled
      return error_template(400, "Login has been disabled by administrator.")
    end

    email = nil
    password = nil
    captcha = nil

    account_type = env.params.query["type"]?
    account_type ||= "invidious"

    captcha_type = env.params.query["captcha"]?
    captcha_type ||= "image"

    templated "user/login"
  end

  def self.login(env)
    locale = env.get("preferences").as(Preferences).locale

    referer = get_referer(env, "/feed/subscriptions")

    if !CONFIG.login_enabled
      return error_template(403, "Login has been disabled by administrator.")
    end

    # https://stackoverflow.com/a/574698
    email = env.params.body["email"]?.try &.downcase.byte_slice(0, 254)
    password = env.params.body["password"]?

    account_type = env.params.query["type"]?
    account_type ||= "invidious"

    case account_type
    when "invidious"
      if email.nil? || email.empty?
        return error_template(401, "User ID is a required field")
      end

      if password.nil? || password.empty?
        return error_template(401, "Password is a required field")
      end

      user = Invidious::Database::Users.select(email: email)

      if user
        if Crypto::Bcrypt::Password.new(user.password.not_nil!).verify(password.byte_slice(0, 55))
          sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
          Invidious::Database::SessionIDs.insert(sid, email)

          env.response.cookies["SID"] = Invidious::User::Cookies.sid(CONFIG.domain, sid)
        else
          return error_template(401, "Wrong username or password")
        end

        # Since this user has already registered, we don't want to overwrite their preferences
        if env.request.cookies["PREFS"]?
          cookie = env.request.cookies["PREFS"]
          cookie.expires = Time.utc(1990, 1, 1)
          env.response.cookies << cookie
        end
      else
        if !CONFIG.registration_enabled
          return error_template(400, "Registration has been disabled by administrator.")
        end

        if password.empty?
          return error_template(401, "Password cannot be empty")
        end

        # See https://security.stackexchange.com/a/39851
        if password.bytesize > 55
          return error_template(400, "Password cannot be longer than 55 characters")
        end

        password = password.byte_slice(0, 55)

        if CONFIG.captcha_enabled
          captcha_type = env.params.body["captcha_type"]?
          answer = env.params.body["answer"]?
          change_type = env.params.body["change_type"]?

          if !captcha_type || change_type
            if change_type
              captcha_type = change_type
            end
            captcha_type ||= "image"

            account_type = "invidious"

            if captcha_type == "image"
              captcha = Invidious::User::Captcha.generate_image(HMAC_KEY)
            else
              captcha = Invidious::User::Captcha.generate_text(HMAC_KEY)
            end

            return templated "user/login"
          end

          tokens = env.params.body.select { |k, _| k.match(/^token\[\d+\]$/) }.map { |_, v| v }

          answer ||= ""
          captcha_type ||= "image"

          case captcha_type
          when "image"
            answer = answer.lstrip('0')
            answer = OpenSSL::HMAC.hexdigest(:sha256, HMAC_KEY, answer)

            begin
              validate_request(tokens[0], answer, env.request, HMAC_KEY, locale)
            rescue ex
              return error_template(400, ex)
            end
          else # "text"
            answer = Digest::MD5.hexdigest(answer.downcase.strip)

            if tokens.empty?
              return error_template(500, "Erroneous CAPTCHA")
            end

            found_valid_captcha = false
            error_exception = Exception.new
            tokens.each do |tok|
              begin
                validate_request(tok, answer, env.request, HMAC_KEY, locale)
                found_valid_captcha = true
              rescue ex
                error_exception = ex
              end
            end

            if !found_valid_captcha
              return error_template(500, error_exception)
            end
          end
        end

        sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
        user, sid = create_user(sid, email, password)

        if language_header = env.request.headers["Accept-Language"]?
          if language = ANG.language_negotiator.best(language_header, LOCALES.keys)
            user.preferences.locale = language.header
          end
        end

        Invidious::Database::Users.insert(user)
        Invidious::Database::SessionIDs.insert(sid, email)

        env.response.cookies["SID"] = Invidious::User::Cookies.sid(CONFIG.domain, sid)

        if env.request.cookies["PREFS"]?
          user.preferences = env.get("preferences").as(Preferences)
          Invidious::Database::Users.update_preferences(user)

          cookie = env.request.cookies["PREFS"]
          cookie.expires = Time.utc(1990, 1, 1)
          env.response.cookies << cookie
        end
      end

      env.redirect referer
    else
      env.redirect referer
    end
  end

  def self.signout(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      return error_template(400, ex)
    end

    Invidious::Database::SessionIDs.delete(sid: sid)

    env.request.cookies.each do |cookie|
      cookie.expires = Time.utc(1990, 1, 1)
      env.response.cookies << cookie
    end

    env.redirect referer
  end
end
