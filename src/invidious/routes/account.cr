{% skip_file if flag?(:api_only) %}

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

    new_passwords = env.params.body.select { |k, _| k.match(/^new_password\[\d+\]$/) }.map { |_, v| v }

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

    Invidious::Database::Users.delete(user)
    Invidious::Database::SessionIDs.delete(email: user.email)

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
    referer = get_referer(env)

    if !user
      return env.redirect "/login?referer=#{URI.encode_path_segment(env.request.resource)}"
    end

    user = user.as(User)
    sid = sid.as(String)
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

    scopes = env.params.body.select { |k, _| k.match(/^scopes\[\d+\]$/) }.map { |_, v| v }
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
end
