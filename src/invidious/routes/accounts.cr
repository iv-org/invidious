require "crotp"
require "./base_route"

# Different routes relating to existing accounts and the control of their data.
class Invidious::Routes::Accounts < Invidious::Routes::BaseRoute
  def setup_2fa_page(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    user = user.as(User)
    sid = sid.as(String)
    csrf_token = generate_response(sid, {":setup_2fa"}, HMAC_KEY, PG_DB)

    db_secret = Random::Secure.random_bytes(16).hexstring
    totp = CrOTP::TOTP.new(db_secret)
    user_secret = totp.base32_secret

    return templated "account/setup_2fa"
  end

  # Endpoint to remove 2fa
  def remove_2fa_page(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    referer = get_referer(env)

    user = env.get("user").as(User)
    sid = env.get("sid").as(String)
    csrf_token = generate_response(sid, {":remove_2fa"}, HMAC_KEY, PG_DB)

    return templated "account/remove_2fa"
  end

  # Remove 2fa post request.
  def remove_2fa(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env, unroll: false)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
    rescue ex
      return error_template(400, ex)
    end

    PG_DB.exec("UPDATE users SET totp_secret = $1 WHERE email = $2", nil, user.email)
  end

  # Setup TOTP (post) request.
  def setup_2fa(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env, unroll: false)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
    rescue ex
      return error_template(400, ex)
    end

    totp_code = env.params.body["totp_code"]?
    db_secret = env.params.body["db_secret"] # Must exist
    if !totp_code
      return error_template(401, translate(locale, "general-totp-empty-field"))
    end

    totp_instance = CrOTP::TOTP.new(db_secret)
    if !totp_instance.verify(totp_code)
      return error_template(401, translate(locale, "general-totp-invalid-code"))
    end

    PG_DB.exec("UPDATE users SET totp_secret = $1 WHERE email = $2", db_secret.to_s, user.email)
  end

  # Validate 2fa code endpoint
  def validate_2fa(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    referer = get_referer(env, unroll: false)

    email = env.params.body["email"]?.try &.downcase.byte_slice(0, 254)
    password = env.params.body["password"]?
    totp_code = env.params.body["totp_code"]?

    # This endpoint is only called when the user has a totp_secret.
    user = PG_DB.query_one?("SELECT * FROM users WHERE email = $1", email, as: User).not_nil!

    if !totp_code
      return error_template(401, translate(locale, "general-totp-empty-field"))
    end

    totp_instance = CrOTP::TOTP.new(user.totp_secret.not_nil!)
    if !totp_instance.verify(totp_code)
      return error_template(401, translate(locale, "general-totp-invalid-code"))
    end

    if Kemal.config.ssl || CONFIG.https_only
      secure = true
    else
      secure = false
    end

    # There are two routes we can go here.
    # 1. Where the user is already logged in and is
    # confirming an dangerous task.
    # 2. The user is logging in.
    #
    # This can be detected by the hidden email and password parameter

    # https://stackoverflow.com/a/574698
    if email && password
      # The rest of the login code.
      if Crypto::Bcrypt::Password.new(user.password.not_nil!).verify(password.byte_slice(0, 55))
        sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
        PG_DB.exec("INSERT INTO session_ids VALUES ($1, $2, $3)", sid, email, Time.utc)

        if CONFIG.domain
          env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", domain: "#{CONFIG.domain}", value: sid, expires: Time.utc + 2.years,
            secure: secure, http_only: true)
        else
          env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", value: sid, expires: Time.utc + 2.years,
            secure: secure, http_only: true)
        end
      else
        return error_template(401, "Wrong username or password")
      end

      # Since this user has already registered, we don't want to overwrite their preferences
      if env.request.cookies["PREFS"]?
        cookie = env.request.cookies["PREFS"]
        cookie.expires = Time.utc(1990, 1, 1)
        env.response.cookies << cookie
      end

      env.redirect referer
    else
      token = env.params.body["csrf_token"]

      begin
        validate_request(token, env.get?("sid").as(String), env.request, HMAC_KEY, PG_DB, locale)
      rescue ex
        return error_template(400, ex)
      end

      if CONFIG.domain
        env.response.cookies["2faVerified"] = HTTP::Cookie.new(name: "2faVerified", domain: "#{CONFIG.domain}", value: "1", expires: Time.utc + 1.hours, secure: secure, http_only: true)
      else
        env.response.cookies["2faVerified"] = HTTP::Cookie.new(name: "2faVerified", value: "1", expires: Time.utc + 1.hours, secure: secure, http_only: true)
      end
    end

    env.redirect referer
  end
end
