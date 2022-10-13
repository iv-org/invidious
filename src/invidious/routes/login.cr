{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Login
  def self.login_page(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    referer = get_referer(env, "/feed/subscriptions")

    return env.redirect referer if user

    if !CONFIG.login_enabled
      return error_template(403, "error_login_disabled")
    end

    account_type = env.params.query["type"]? || "invidious"

    captcha_type = User::Captcha.parse_type(env.params.query)
    captcha = User::Captcha.generate(captcha_type)

    return templated "user/login"
  end

  def self.login(env)
    locale = env.get("preferences").as(Preferences).locale
    referer = get_referer(env, "/feed/subscriptions")

    if !CONFIG.login_enabled
      return error_template(403, "error_login_disabled")
    end

    # Verify captcha
    if CONFIG.captcha_enabled
      begin
        captcha_verified = User::Captcha.verify(env)
        raise InfoException.new("error_invalid_captcha") if !captcha_verified
      rescue ex
        return error_template(400, ex)
      end
    end

    account_type = env.params.query["type"]? || "invidious"

    case account_type
    when "invidious"
      # https://stackoverflow.com/a/574698
      username = env.params.body["username"]?.try &.downcase.byte_slice(0, 254)
      password = env.params.body["password"]?

      if username.nil? || username.empty? || password.nil? || password.empty?
        return error_template(403, "error_invalid_username_or_password")
      end

      user = Database::Users.select(email: username)

      if !user.nil? && user.validate_password(password)
        # Generate session ID and store it.
        sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
        begin
          Database::SessionIDs.insert(sid, username)
        rescue ex
          return error_template(500, "error_database_unavailable")
        end

        # Generate cookies
        env.response.cookies["SID"] = User::Cookies.sid(CONFIG.domain, sid)
        env.response.cookies["PREFS"] = User::Cookies.prefs(CONFIG.domain, user.preferences)
      else
        return error_template(403, "error_invalid_username_or_password")
      end
    end

    return env.redirect referer
  end

  def self.register_page(env)
    locale = env.get("preferences").as(Preferences).locale
    referer = get_referer(env, "/feed/subscriptions")

    return env.redirect referer if env.get? "user"

    if !CONFIG.registration_enabled
      return error_template(403, "error_registration_disabled")
    end

    captcha_type = User::Captcha.parse_type(env.params.query)
    captcha = User::Captcha.generate(captcha_type)

    return templated "user/register"
  end

  def self.register(env)
    locale = env.get("preferences").as(Preferences).locale
    referer = get_referer(env, "/feed/subscriptions")

    if !CONFIG.registration_enabled
      return error_template(403, "error_registration_disabled")
    end

    # https://stackoverflow.com/a/574698
    username = env.params.body["username"]?.try &.downcase.byte_slice(0, 254)
    password = env.params.body["password"]?
    confirm = env.params.body["confirm"]?

    if username.nil? || username.empty?
      return error_template(400, "error_required_field_username")
    end

    if password.nil? || password.empty? || confirm.nil? || confirm.empty?
      return error_template(400, "error_required_field_password")
    end

    if password != confirm
      return error_template(400, "error_passwords_dont_match")
    end

    # TODO: find a way to allow longer passwords
    # See https://security.stackexchange.com/a/39851
    if password.bytesize > 55
      return error_template(400, "Password cannot be longer than 55 characters")
    end

    # Verify captcha
    if CONFIG.captcha_enabled
      begin
        captcha_verified = User::Captcha.verify(env)
        raise InfoException.new("error_invalid_captcha") if !captcha_verified
      rescue ex
        return error_template(400, ex)
      end
    end

    # Make sure that user doesn't exist!!
    user_check = Database::Users.select(email: username)
    if !user_check.nil?
      return error_template(400, "error_username_already_registered")
    end

    # Generate session ID
    sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
    user = User.create(sid, username, password)

    # Use the preferences from user cookie (pre-registration)
    # and save them into the account. Otherwise, make a new one.
    if env.request.cookies["PREFS"]?
      user.preferences = env.get("preferences").as(Preferences)
    end

    # Create the proper DN
    # TODO: use DB transaction here to avoid corrupted states
    Database::Users.insert(user)
    Database::SessionIDs.insert(sid, username)

    view_name = "subscriptions_#{sha256(user.email)}"
    PG_DB.exec("CREATE MATERIALIZED VIEW #{view_name} AS #{MATERIALIZED_VIEW_SQL.call(user.email)}")

    # Generate cookies
    env.response.cookies["SID"] = User::Cookies.sid(CONFIG.domain, sid)
    env.response.cookies["PREFS"] = User::Cookies.prefs(CONFIG.domain, user.preferences)

    return env.redirect referer
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

    return env.redirect referer
  end
end
