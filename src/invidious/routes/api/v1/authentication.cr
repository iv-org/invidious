module Invidious::Routes::API::V1::Authentication
  def self.register(env)
    env.response.content_type = "application/json"
    if !CONFIG.registration_enabled
      return error_json(400, "Registration has been disabled by administrator")
    else
      # check if user is registering or responding to captcha
      begin
        creds = Credentials.from_json(env.request.body || "{}")
      rescue JSON::SerializableError
        creds = nil
      end

      # begin
      #   captcha_response = CaptchaResponse.from_json(env.request.body || "{}")
      # rescue JSON::SerializableError
      #   captcha_response = nil
      # end

      if creds
        # user is registering
        username = creds.username
        password = creds.password

        if username.nil? || username.empty?
          return error_json(401, "User ID is a required field")
        end

        if password.nil? || password.empty?
          return error_json(401, "Password is a required field")
        end

        if username.empty?
          return error_json(401, "Username cannot be empty")
        end

        if password.empty?
          return error_json(401, "Password cannot be empty")
        end

        if username.bytesize > 254
          return error_json(401)
        end

        # See https://security.stackexchange.com/a/39851
        if password.bytesize > 55
          return error_json(401, "Password cannot be longer than 55 characters")
        end

        username = username.byte_slice(0, 254)
        password = password.byte_slice(0, 55)

        if CONFIG.captcha_enabled
          # if captcha is enabled, send captcha
          captcha = Invidious::User::Captcha.generate_text(HMAC_KEY)
          # puts captcha
          return captcha
        end
      end
      # if captcha_response
      #   # process captcha response
      #   answer = captcha_response.answer
      #   answer = answer.lstrip('0')
      #   answer = OpenSSL::HMAC.hexdigest(:sha256, HMAC_KEY, answer)
      #   begin
      #     validate_request(, answer, env.request, HMAC_KEY, locale)
      #   rescue ex
      #     return error_jsonror(400, ex)
      #   end
      # end
      # create user if we made it past credentials and captcha
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
    end
  end

  def self.login(env)
    env.response.content_type = "application/json"
    # locale = env.get("preferences").as(Preferences).locale
    if !CONFIG.login_enabled
      return error_json(400, "Login has been disabled by administrator")
    else
      creds = Credentials.from_json(env.request.body || "{}")
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

  property answer : String
  # property tokens : Array()
end

struct Credentials
  include JSON::Serializable
  include YAML::Serializable

  property username : String
  property password : String
  property token : String
end
