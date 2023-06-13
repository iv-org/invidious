module Invidious::Routes::API::V1::Authentication
  def self.register(env)
    env.response.content_type = "application/json"
    body_json = env.request.body || "{}"
    if CONFIG.registration_enabled
      creds = nil
      begin
        creds = Credentials.from_json(body_json)
      rescue
      end
      # get user info
      if creds
        locale = env.get("preferences").as(Preferences).locale
        username = creds.username.downcase
        password = creds.password
        username = "" if username.nil?
        password = "" if password.nil?

        if username.empty?
          return error_json(401, "Username cannot be empty")
        end

        if password.empty?
          return error_json(401, "Password cannot be empty")
        end

        if username.bytesize > 254
          return error_json(401, "Username cannot be longer than 254 characters")
        end

        # See https://security.stackexchange.com/a/39851
        if password.bytesize > 55
          return error_json(401, "Password cannot be longer than 55 characters")
        end

        username = username.byte_slice(0, 254)
        password = password.byte_slice(0, 55)
        # send captcha if enabled
        if CONFIG.captcha_enabled
          # captcha_response = nil
          captcha_response = CaptchaResponse.from_json(body_json)
          # begin
          # rescue ex

          # end
          if captcha_response
            answer = captcha_response.answer
            tokens = captcha_response.tokens
            answer = Digest::MD5.hexdigest(answer.downcase.strip)
            if tokens.empty?
              return error_json(500, "Erroneous CAPTCHA")
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
              return error_json(500, error_exception)
            end
          else
            # send captcha
            captcha = Invidious::User::Captcha.generate_text(HMAC_KEY, ":register")
            # puts captcha
            captcha_request = JSON.build do |json|
              json.object do
                json.field "question", captcha["question"]
                json.field "tokens", captcha["tokens"]
              end
            end
            return captcha_request
          end
        end
        # create user
        sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
        user, sid = create_user(sid, username, password)
        Invidious::Database::Users.insert(user)
        Invidious::Database::SessionIDs.insert(sid, username)
        # send user info
        if token = Invidious::Database::SessionIDs.select_one(sid: sid)
          response = JSON.build do |json|
            json.object do
              json.field "session", token[:session]
              json.field "issued", token[:issued].to_unix
            end
          end
          return response
        else
          return error_json(500, "Token not found")
        end
      else
        return error_json(401, "No credentials")
      end
    else
      return error_json(400, "Registration has been disabled by administrator")
    end
  end

  def self.captcha(env)
    if CONFIG.registration_enabled
      if CONFIG.captcha_enabled
        captcha_response = nil
        begin
          captcha_response = CaptchaResponse.from_json(env.request.body || "{}")
        rescue
        end
        if captcha_response
          # process captcha response
          locale = env.get("preferences").as(Preferences).locale

          username = captcha_response.username.downcase
          password = captcha_response.password
          answer = captcha_response.answer
          tokens = captcha_response.tokens

          if username.empty?
            return error_json(401, "Username cannot be empty")
          end

          if password.empty?
            return error_json(401, "Password cannot be empty")
          end

          if username.bytesize > 254
            return error_json(401, "Username cannot be longer than 254 characters")
          end

          # See https://security.stackexchange.com/a/39851
          if password.bytesize > 55
            return error_json(401, "Password cannot be longer than 55 characters")
          end

          username = username.byte_slice(0, 254)
          password = password.byte_slice(0, 55)

          answer = Digest::MD5.hexdigest(answer.downcase.strip)

          if tokens.empty?
            return error_json(500, "Erroneous CAPTCHA")
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
            return error_json(500, error_exception)
          end
          # create user
          sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
          user, sid = create_user(sid, username, password)
          Invidious::Database::Users.insert(user)
          Invidious::Database::SessionIDs.insert(sid, username)
          # send user info
          if token = Invidious::Database::SessionIDs.select_one(sid: sid)
            response = JSON.build do |json|
              json.object do
                json.field "session", token[:session]
                json.field "issued", token[:issued].to_unix
              end
            end
            return response
          else
            return error_json(500, "Token not found")
          end
        else
          return error_json(401, "No response")
        end
      else
        return error_json(400, "Captcha has been disabled by administrator")
      end
    else
      return error_json(400, "Registration has been disabled by administrator")
    end
  end

  def self.login(env)
    env.response.content_type = "application/json"
    # locale = env.get("preferences").as(Preferences).locale
    if !CONFIG.login_enabled
      return error_json(400, "Login has been disabled by administrator")
    else
      creds = CredentialsLogin.from_json(env.request.body || "{}")
      user = Invidious::Database::Users.select(email: creds.username)
      old_sid = creds.token
      if user
        if Crypto::Bcrypt::Password.new(user.password.not_nil!).verify(creds.password.byte_slice(0, 55))
          sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
          Invidious::Database::SessionIDs.insert(sid: sid, email: creds.username)
          if old_sid != ""
            Invidious::Database::SessionIDs.delete(sid: old_sid)
          end
          if token = Invidious::Database::SessionIDs.select_one(sid: sid)
            response = JSON.build do |json|
              json.object do
                json.field "session", token[:session]
                json.field "issued", token[:issued].to_unix
              end
            end
            return response
          else
            return error_json(500, "Token not found")
          end
        else
          return error_json(401, "Wrong username or password")
        end
      else
        return error_json(400, "Not registered")
      end
    end
  end

  def self.signout(env)
    env.response.content_type = "application/json"
    user = env.get("user").as(User)
    sid = env.request.cookies["SID"].value
    Invidious::Database::SessionIDs.delete(sid: sid)
    env.response.status_code = 200
  end
end

struct CaptchaResponse
  include JSON::Serializable
  include YAML::Serializable

  property username : String
  property password : String
  property answer : String
  property tokens : Array(String)
end

struct Credentials
  include JSON::Serializable
  include YAML::Serializable

  property username : String
  property password : String
end

struct CredentialsLogin
  include JSON::Serializable
  include YAML::Serializable

  property username : String
  property password : String
  property token : String
end
