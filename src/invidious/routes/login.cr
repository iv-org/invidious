{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Login
  def self.login_page(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"

    return env.redirect "/feed/subscriptions" if user

    if !CONFIG.login_enabled
      return error_template(400, "Login has been disabled by administrator.")
    end

    referer = get_referer(env, "/feed/subscriptions")

    email = nil
    password = nil
    captcha = nil

    account_type = env.params.query["type"]?
    account_type ||= "invidious"

    captcha_type = env.params.query["captcha"]?
    captcha_type ||= "image"

    tfa = env.params.query["tfa"]?
    prompt = nil

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
    when "google"
      tfa_code = env.params.body["tfa"]?.try &.lchop("G-")
      traceback = IO::Memory.new

      # See https://github.com/ytdl-org/youtube-dl/blob/2019.04.07/youtube_dl/extractor/youtube.py#L82
      begin
        client = nil # Declare variable
        {% unless flag?(:disable_quic) %}
          client = CONFIG.use_quic ? QUIC::Client.new(LOGIN_URL) : HTTP::Client.new(LOGIN_URL)
        {% else %}
          client = HTTP::Client.new(LOGIN_URL)
        {% end %}

        headers = HTTP::Headers.new

        login_page = client.get("/ServiceLogin")
        headers = login_page.cookies.add_request_headers(headers)

        lookup_req = {
          email, nil, [] of String, nil, "US", nil, nil, 2, false, true,
          {nil, nil,
           {2, 1, nil, 1,
            "https://accounts.google.com/ServiceLogin?passive=true&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Fnext%3D%252F%26action_handle_signin%3Dtrue%26hl%3Den%26app%3Ddesktop%26feature%3Dsign_in_button&hl=en&service=youtube&uilel=3&requestPath=%2FServiceLogin&Page=PasswordSeparationSignIn",
            nil, [] of String, 4},
           1,
           {nil, nil, [] of String},
           nil, nil, nil, true,
          },
          email,
        }.to_json

        traceback << "Getting lookup..."

        headers["Content-Type"] = "application/x-www-form-urlencoded;charset=utf-8"
        headers["Google-Accounts-XSRF"] = "1"

        response = client.post("/_/signin/sl/lookup", headers, login_req(lookup_req))
        lookup_results = JSON.parse(response.body[5..-1])

        traceback << "done, returned #{response.status_code}.<br/>"

        user_hash = lookup_results[0][2]

        if token = env.params.body["token"]?
          answer = env.params.body["answer"]?
          captcha = {token, answer}
        else
          captcha = nil
        end

        challenge_req = {
          user_hash, nil, 1, nil,
          {1, nil, nil, nil,
           {password, captcha, true},
          },
          {nil, nil,
           {2, 1, nil, 1,
            "https://accounts.google.com/ServiceLogin?passive=true&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Fnext%3D%252F%26action_handle_signin%3Dtrue%26hl%3Den%26app%3Ddesktop%26feature%3Dsign_in_button&hl=en&service=youtube&uilel=3&requestPath=%2FServiceLogin&Page=PasswordSeparationSignIn",
            nil, [] of String, 4},
           1,
           {nil, nil, [] of String},
           nil, nil, nil, true,
          },
        }.to_json

        traceback << "Getting challenge..."

        response = client.post("/_/signin/sl/challenge", headers, login_req(challenge_req))
        headers = response.cookies.add_request_headers(headers)
        challenge_results = JSON.parse(response.body[5..-1])

        traceback << "done, returned #{response.status_code}.<br/>"

        headers["Cookie"] = URI.decode_www_form(headers["Cookie"])

        if challenge_results[0][3]?.try &.== 7
          return error_template(423, "Account has temporarily been disabled")
        end

        if token = challenge_results[0][-1]?.try &.[-1]?.try &.as_h?.try &.["5001"]?.try &.[-1].as_a?.try &.[-1].as_s
          account_type = "google"
          captcha_type = "image"
          prompt = nil
          tfa = tfa_code
          captcha = {tokens: [token], question: ""}

          return templated "user/login"
        end

        if challenge_results[0][-1]?.try &.[5] == "INCORRECT_ANSWER_ENTERED"
          return error_template(401, "Incorrect password")
        end

        prompt_type = challenge_results[0][-1]?.try &.[0].as_a?.try &.[0][2]?
        if {"TWO_STEP_VERIFICATION", "LOGIN_CHALLENGE"}.includes? prompt_type
          traceback << "Handling prompt #{prompt_type}.<br/>"
          case prompt_type
          when "TWO_STEP_VERIFICATION"
            prompt_type = 2
          else # "LOGIN_CHALLENGE"
            prompt_type = 4
          end

          # Prefer Authenticator app and SMS over unsupported protocols
          if !{6, 9, 12, 15}.includes?(challenge_results[0][-1][0][0][8].as_i) && prompt_type == 2
            tfa = challenge_results[0][-1][0].as_a.select { |auth_type| {6, 9, 12, 15}.includes? auth_type[8] }[0]

            traceback << "Selecting challenge #{tfa[8]}..."
            select_challenge = {prompt_type, nil, nil, nil, {tfa[8]}}.to_json

            tl = challenge_results[1][2]

            tfa = client.post("/_/signin/selectchallenge?TL=#{tl}", headers, login_req(select_challenge)).body
            tfa = tfa[5..-1]
            tfa = JSON.parse(tfa)[0][-1]

            traceback << "done.<br/>"
          else
            traceback << "Using challenge #{challenge_results[0][-1][0][0][8]}.<br/>"
            tfa = challenge_results[0][-1][0][0]
          end

          if tfa[5] == "QUOTA_EXCEEDED"
            return error_template(423, "Quota exceeded, try again in a few hours")
          end

          if !tfa_code
            account_type = "google"
            captcha_type = "image"

            case tfa[8]
            when 6, 9
              prompt = "Google verification code"
            when 12
              prompt = "Login verification, recovery email: #{tfa[-1][tfa[-1].as_h.keys[0]][0]}"
            when 15
              prompt = "Login verification, security question: #{tfa[-1][tfa[-1].as_h.keys[0]][0]}"
            else
              prompt = "Google verification code"
            end

            tfa = nil
            captcha = nil
            return templated "user/login"
          end

          tl = challenge_results[1][2]

          request_type = tfa[8]
          case request_type
          when 6 # Authenticator app
            tfa_req = {
              user_hash, nil, 2, nil,
              {6, nil, nil, nil, nil,
               {tfa_code, false},
              },
            }.to_json
          when 9 # Voice or text message
            tfa_req = {
              user_hash, nil, 2, nil,
              {9, nil, nil, nil, nil, nil, nil, nil,
               {nil, tfa_code, false, 2},
              },
            }.to_json
          when 12 # Recovery email
            tfa_req = {
              user_hash, nil, 4, nil,
              {12, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
               {tfa_code},
              },
            }.to_json
          when 15 # Security question
            tfa_req = {
              user_hash, nil, 5, nil,
              {15, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
               {tfa_code},
              },
            }.to_json
          else
            return error_template(500, "Unable to log in, make sure two-factor authentication (Authenticator or SMS) is turned on.")
          end

          traceback << "Submitting challenge..."

          response = client.post("/_/signin/challenge?hl=en&TL=#{tl}", headers, login_req(tfa_req))
          headers = response.cookies.add_request_headers(headers)
          challenge_results = JSON.parse(response.body[5..-1])

          if (challenge_results[0][-1]?.try &.[5] == "INCORRECT_ANSWER_ENTERED") ||
             (challenge_results[0][-1]?.try &.[5] == "INVALID_INPUT")
            return error_template(401, "Invalid TFA code")
          end

          traceback << "done.<br/>"
        end

        traceback << "Logging in..."

        location = URI.parse(challenge_results[0][-1][2].to_s)
        cookies = HTTP::Cookies.from_client_headers(headers)

        headers.delete("Content-Type")
        headers.delete("Google-Accounts-XSRF")

        loop do
          if !location || location.path == "/ManageAccount"
            break
          end

          # Occasionally there will be a second page after login confirming
          # the user's phone number ("/b/0/SmsAuthInterstitial"), which we currently don't handle.

          if location.path.starts_with? "/b/0/SmsAuthInterstitial"
            traceback << "Unhandled dialog /b/0/SmsAuthInterstitial."
          end

          login = client.get(location.request_target, headers)

          headers = login.cookies.add_request_headers(headers)
          location = login.headers["Location"]?.try { |u| URI.parse(u) }
        end

        cookies = HTTP::Cookies.from_client_headers(headers)
        sid = cookies["SID"]?.try &.value
        if !sid
          raise "Couldn't get SID."
        end

        user, sid = get_user(sid, headers)

        # We are now logged in
        traceback << "done.<br/>"

        host = URI.parse(env.request.headers["Host"]).host

        cookies.each do |cookie|
          cookie.secure = Invidious::User::Cookies::SECURE

          if cookie.extension
            cookie.extension = cookie.extension.not_nil!.gsub(".youtube.com", host)
            cookie.extension = cookie.extension.not_nil!.gsub("Secure; ", "")
          end
          env.response.cookies << cookie
        end

        if env.request.cookies["PREFS"]?
          user.preferences = env.get("preferences").as(Preferences)
          Invidious::Database::Users.update_preferences(user)

          cookie = env.request.cookies["PREFS"]
          cookie.expires = Time.utc(1990, 1, 1)
          env.response.cookies << cookie
        end

        env.redirect referer
      rescue ex
        traceback.rewind
        # error_message = translate(locale, "Login failed. This may be because two-factor authentication is not turned on for your account.")
        error_message = %(#{ex.message}<br/>Traceback:<br/><div style="padding-left:2em" id="traceback">#{traceback.gets_to_end}</div>)
        return error_template(500, error_message)
      end
    when "invidious"
      if !email
        return error_template(401, "User ID is a required field")
      end

      if !password
        return error_template(401, "Password is a required field")
      end

      user = Invidious::Database::Users.select(email: email)

      if user
        if !user.password
          return error_template(400, "Please sign in using 'Log in with Google'")
        end

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
            tfa = false
            prompt = ""

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

  def self.captcha(env)
    headers = HTTP::Headers{":authority" => "accounts.google.com"}
    response = YT_POOL.client &.get(env.request.resource, headers)
    env.response.headers["Content-Type"] = response.headers["Content-Type"]
    response.body
  end
end
