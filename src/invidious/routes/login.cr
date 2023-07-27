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
      return error_template(401, "Wrong username or password")
    end

    env.redirect referer
  end

  def self.signup_page(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"

    referer = get_referer(env, "/feed/subscriptions")

    return env.redirect referer if user

    if !CONFIG.registration_enabled
      return error_template(400, "Registration has been disabled by administrator.")
    end

    email = nil
    password = nil
    captcha = nil

    captcha_type = env.params.query["captcha"]?
    captcha_type ||= "image"

    templated "user/register"
  end

  def self.signup(env)
    locale = env.get("preferences").as(Preferences).locale
    referer = get_referer(env, "/feed/subscriptions")

    if !CONFIG.registration_enabled
      return error_template(400, "Registration has been disabled by administrator.")
    end

    email = env.params.body["email"]?.try &.downcase.byte_slice(0, 254)
    password = env.params.body["password"]?

    if email.nil? || email.empty?
      return error_template(401, "User ID is a required field")
    end

    if password.nil? || password.empty?
      return error_template(401, "Password cannot be empty")
    end

    # See https://security.stackexchange.com/a/39851
    if password.bytesize > 55
      return error_template(400, "Password cannot be longer than 55 characters")
    end

    password = password.byte_slice(0, 55)

    if CONFIG.captcha_enabled
      # Fetch information needed to initially display captcha
      #
      # We start out with an image captcha.
      captcha, captcha_type, change_type = Invidious::User::Captcha.get_captcha_display_info(env, "image")
      return templated "user/captcha"
    end

    self.register_user(env, email, password)

    env.redirect referer
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

  # Validates and displays captchas to the end user
  def self.captcha(env)
    if !CONFIG.captcha_enabled
      error_template(403, "Administrator has disabled this endpoint")
    end

    begin
      email = env.params.body["email"]?
      password = env.params.body["password"]?
    rescue ex : KeyError
      return error_template(400, "Invalid request")
    end

    email = email.not_nil!
    password = password.not_nil!

    locale = env.get("preferences").as(Preferences).locale
    referer = get_referer(env, "/feed/subscriptions")

    captcha_type = env.params.body["captcha_type"]?
    answer = env.params.body["answer"]?
    change_type = env.params.body["change_type"]?

    # User requests to change captcha displayed
    if !captcha_type || change_type
      LOGGER.trace("User requests to change Captcha")

      captcha, captcha_type, change_type = Invidious::User::Captcha.get_captcha_display_info(env, change_type)
      return templated "user/captcha"
    end

    LOGGER.trace("Validating new user with Captcha")

    tokens = env.params.body.select { |k, _| k.match(/^token\[\d+\]$/) }.map { |_, v| v }

    # Captcha validation

    answer ||= ""
    captcha_type ||= "image"

    case captcha_type
    when "image"
      LOGGER.trace("Validating image Captcha")

      answer = answer.lstrip('0')
      answer = OpenSSL::HMAC.hexdigest(:sha256, HMAC_KEY, answer)

      begin
        validate_request(tokens[0], answer, env.request, HMAC_KEY, locale)
      rescue ex
        return error_template(400, "Erroneous CAPTCHA")
      end
    else # "text"
      answer = Digest::MD5.hexdigest(answer.downcase.strip)

      if tokens.empty?
        return error_template(400, "Erroneous CAPTCHA")
      end

      # Text Captcha Validation
      # There's a possibility that there could be multiple tokens and therefore we'd need to
      # check them all and only error once we've made sure that none of them passes the check.
      found_valid_captcha = false
      error_exception = Exception.new

      tokens.each do |tok|
        begin
          validate_request(tok, answer, env.request, HMAC_KEY, locale)
          found_valid_captcha = true

          break
        rescue ex
          error_exception = ex
        end
      end

      # Error when validation fail
      if !found_valid_captcha
        return error_template(400, "Erroneous CAPTCHA")
      end
    end

    self.register_user(env, email, password)

    env.redirect referer
  end

  # Private method to register an user within a database after
  # validation
  private def self.register_user(env, email, password)
    sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
    user, sid = create_user(sid, email, password)

    if language_header = env.request.headers["Accept-Language"]?
      if language = ANG.language_negotiator.best(language_header, LOCALES.keys)
        user.preferences.locale = language.header
      end
    end

    Invidious::Database::Users.insert(user)
    Invidious::Database::SessionIDs.insert(sid, email)

    view_name = "subscriptions_#{sha256(user.email)}"
    PG_DB.exec("CREATE MATERIALIZED VIEW #{view_name} AS #{MATERIALIZED_VIEW_SQL.call(user.email)}")

    env.response.cookies["SID"] = Invidious::User::Cookies.sid(CONFIG.domain, sid)

    if env.request.cookies["PREFS"]?
      user.preferences = env.get("preferences").as(Preferences)
      Invidious::Database::Users.update_preferences(user)

      cookie = env.request.cookies["PREFS"]
      cookie.expires = Time.utc(1990, 1, 1)
      env.response.cookies << cookie
    end

    LOGGER.debug("A new user has been registered")
  end
end
