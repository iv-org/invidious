{% skip_file if flag?(:api_only) %}

require "crotp"

module Invidious::Routes::Account
  extend self

  # -------------------
  #  Password update
  # -------------------

  # Show the password change interface (GET request)
  def get_change_password(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)

    if user.totp_secret && env.request.cookies["2faVerified"]?.try &.value != "1" || nil
      return call_totp_validator(env, user, sid, locale)
    end

    csrf_token = generate_response(sid, {":change_password"}, HMAC_KEY)

    templated "user/change_password"
  end

  # Handle the password change (POST request)
  def post_change_password(env)
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

    password = env.params.body["password"]?
    if password.nil? || password.empty?
      return error_template(401, "Password is a required field")
    end

    new_passwords = env.params.body.select { |k, v| k.match(/^new_password\[\d+\]$/) }.map { |k, v| v }

    if new_passwords.size <= 1 || new_passwords.uniq.size != 1
      return error_template(400, "New passwords must match")
    end

    new_password = new_passwords.uniq[0]
    if new_password.empty?
      return error_template(401, "Password cannot be empty")
    end

    if new_password.bytesize > 55
      return error_template(400, "Password cannot be longer than 55 characters")
    end

    if !Crypto::Bcrypt::Password.new(user.password.not_nil!).verify(password.byte_slice(0, 55))
      return error_template(401, "Incorrect password")
    end

    new_password = Crypto::Bcrypt::Password.create(new_password, cost: 10)
    Invidious::Database::Users.update_password(user, new_password.to_s)

    env.redirect referer
  end

  # -------------------
  #  Account deletion
  # -------------------

  # Show the account deletion confirmation prompt (GET request)
  def get_delete(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)

    if user.totp_secret && env.request.cookies["2faVerified"]?.try &.value != "1" || nil
      return call_totp_validator(env, user, sid, locale)
    end

    csrf_token = generate_response(sid, {":delete_account"}, HMAC_KEY)

    templated "user/delete_account"
  end

  # Handle the account deletion (POST request)
  def post_delete(env)
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

    view_name = "subscriptions_#{sha256(user.email)}"
    Invidious::Database::Users.delete(user)
    Invidious::Database::SessionIDs.delete(email: user.email)
    PG_DB.exec("DROP MATERIALIZED VIEW #{view_name}")

    env.request.cookies.each do |cookie|
      cookie.expires = Time.utc(1990, 1, 1)
      env.response.cookies << cookie
    end

    env.redirect referer
  end

  # -------------------
  #  Clear history
  # -------------------

  # Show the watch history deletion confirmation prompt (GET request)
  def get_clear_history(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)
    csrf_token = generate_response(sid, {":clear_watch_history"}, HMAC_KEY)

    templated "user/clear_watch_history"
  end

  # Handle the watch history clearing (POST request)
  def post_clear_history(env)
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

    Invidious::Database::Users.clear_watch_history(user)
    env.redirect referer
  end

  # -------------------
  #  Authorize tokens
  # -------------------

  # Show the "authorize token?" confirmation prompt (GET request)
  def get_authorize_token(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"

    user = user.as(User)
    sid = sid.as(String)

    if user.totp_secret && env.request.cookies["2faVerified"]?.try &.value != "1" || nil
      return call_totp_validator(env, user, sid, locale)
    end

    referer = get_referer(env)

    if !user
      return env.redirect "/login?referer=#{URI.encode_path_segment(env.request.resource)}"
    end

    csrf_token = generate_response(sid, {":authorize_token"}, HMAC_KEY)

    scopes = env.params.query["scopes"]?.try &.split(",")
    scopes ||= [] of String

    callback_url = env.params.query["callback_url"]?
    if callback_url
      callback_url = URI.parse(callback_url)
    end

    expire = env.params.query["expire"]?.try &.to_i?

    templated "user/authorize_token"
  end

  # Handle token authorization (POST request)
  def post_authorize_token(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = env.get("user").as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      return error_template(400, ex)
    end

    scopes = env.params.body.select { |k, v| k.match(/^scopes\[\d+\]$/) }.map { |k, v| v }
    callback_url = env.params.body["callbackUrl"]?
    expire = env.params.body["expire"]?.try &.to_i?

    access_token = generate_token(user.email, scopes, expire, HMAC_KEY)

    if callback_url
      access_token = URI.encode_www_form(access_token)
      url = URI.parse(callback_url)

      if url.query
        query = HTTP::Params.parse(url.query.not_nil!)
      else
        query = HTTP::Params.new
      end

      query["token"] = access_token
      query["username"] = URI.encode_path_segment(user.email)
      url.query = query.to_s

      env.redirect url.to_s
    else
      csrf_token = ""
      env.set "access_token", access_token
      templated "user/authorize_token"
    end
  end

  # -------------------
  #  Manage tokens
  # -------------------

  # Show the token manager page (GET request)
  def token_manager(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env, "/subscription_manager")

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    tokens = Invidious::Database::SessionIDs.select_all(user.email)

    templated "user/token_manager"
  end

  # -------------------
  #  AJAX for tokens
  # -------------------

  # Handle internal (non-API) token actions (POST request)
  def token_ajax(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    redirect = env.params.query["redirect"]?
    redirect ||= "true"
    redirect = redirect == "true"

    if !user
      if redirect
        return env.redirect referer
      else
        return error_json(403, "No such user")
      end
    end

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      if redirect
        return error_template(400, ex)
      else
        return error_json(400, ex)
      end
    end

    if env.params.query["action_revoke_token"]?
      action = "action_revoke_token"
    else
      return env.redirect referer
    end

    session = env.params.query["session"]?
    session ||= ""

    case action
    when .starts_with? "action_revoke_token"
      Invidious::Database::SessionIDs.delete(sid: session, email: user.email)
    else
      return error_json(400, "Unsupported action #{action}")
    end

    if redirect
      return env.redirect referer
    else
      env.response.content_type = "application/json"
      return "{}"
    end
  end

  # -------------------
  # 2fa through OTP handling
  # -------------------

  # Templates the page to setup 2fa on an user account
  def setup_2fa_page(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env, unroll: false)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)
    csrf_token = generate_response(sid, {":2fa/setup"}, HMAC_KEY)

    db_secret = Random::Secure.random_bytes(16).hexstring
    totp = CrOTP::TOTP.new(db_secret)
    user_secret = totp.base32_secret

    return templated "user/setup_2fa"
  end

  # Handles requests to setup 2fa on an user account
  def setup_2fa(env)
    locale = env.get("preferences").as(Preferences).locale

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
      validate_request(token, sid, env.request, HMAC_KEY, locale)
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
    env.redirect referer
  end

  # Handles requests to validate a TOTP code on an user account
  def validate_2fa(env)
    locale = env.get("preferences").as(Preferences).locale
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

    #
    # The validate_2fa method is used in two cases:
    # 1. To authenticate the user when logging in
    # 2. To verify that the user wishes to proceed with a dangerous action.
    #
    # As we've verified that the totp given is correct we can now proceed with
    # authenticating and/or redirecting the user back to where they came from
    #

    logging_in = (email && password)

    if logging_in
      # Authenticate the user. The rest follows the code in login.cr
      if Crypto::Bcrypt::Password.new(user.password.not_nil!).verify(password.not_nil!.byte_slice(0, 55))
        #
        sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
        PG_DB.exec("INSERT INTO session_ids VALUES ($1, $2, $3)", sid, email, Time.utc)

        if CONFIG.domain
          env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", domain: "#{CONFIG.domain}", value: sid, expires: Time.utc + 2.years,
            secure: secure, http_only: true, path: "/")
        else
          env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", value: sid, expires: Time.utc + 2.years,
            secure: secure, http_only: true, path: "/")
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
        validate_request(token, env.get?("sid").as(String), env.request, HMAC_KEY, locale)
      rescue ex
        return error_template(400, ex)
      end

      if CONFIG.domain
        env.response.cookies["2faVerified"] = HTTP::Cookie.new(name: "2faVerified", domain: "#{CONFIG.domain}", value: "1", expires: Time.utc + 5.minutes, secure: secure, http_only: true, path: "/")
      else
        env.response.cookies["2faVerified"] = HTTP::Cookie.new(name: "2faVerified", value: "1", expires: Time.utc + 5.minutes, secure: secure, http_only: true, path: "/")
      end
    end

    env.redirect referer
  end

  # Templates the page to remove 2fa on an user account
  def remove_2fa_page(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env, unroll: false)

    if !user || user.is_a? User && !user.totp_secret
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)
    csrf_token = generate_response(sid, {":2fa/remove"}, HMAC_KEY)

    return templated "user/remove_2fa"
  end

  # Handles requests to remove 2fa on an user account
  def remove_2fa(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env, unroll: false)

    if !user || user.is_a? User && !user.totp_secret
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

    PG_DB.exec("UPDATE users SET totp_secret = $1 WHERE email = $2", nil, user.email)
    env.redirect referer
  end
end
