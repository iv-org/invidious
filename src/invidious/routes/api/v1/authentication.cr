module Invidious::Routes::API::V1::Authentication
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
        if Crypto::Bcrypt::Password.new(creds.password).verify(creds.password.byte_slice(0, 55))
          sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
          Invidious::Database::SessionIDs.insert(sid, creds.username)
          if old_sid != ""
            Invidious::Database::SessionIDs.delete(old_sid)
          end
          token = Invidious::Database::SessionIDs.select_token(sid)
          response = JSON.build do |json|
            json.object do
              json.field "session", token[:session]
              json.field "issued", token[:issued].to_unix
            end
          end
          return response
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

struct Credentials
  include JSON::Serializable
  include YAML::Serializable

  property username : String
  property password : String
  property token : String
end
