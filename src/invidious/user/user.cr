require "db"

struct Invidious::User
  include DB::Serializable

  property updated : Time
  property notifications : Array(String) = [] of String
  property subscriptions : Array(String) = [] of String
  property email : String

  @[DB::Field(converter: Invidious::User::PreferencesConverter)]
  property preferences : Preferences
  property password : String?
  property token : String
  property watched : Array(String) = [] of String
  property feed_needs_update : Bool? = true

  def initialize(*, @email, @token, @password)
    @updated = Time.utc
    @preferences = Preferences.new(CONFIG.default_user_preferences.to_tuple)
  end

  def self.create(sid, email, password) : User
    hashed_pwd = Crypto::Bcrypt::Password.create(password, cost: 10)
    token = Base64.urlsafe_encode(Random::Secure.random_bytes(32))

    return User.new(email: email, token: token, password: hashed_pwd.to_s)
  end

  def validate_password(password : String) : Bool
    # Damned Google accounts were stored with a nil password
    stored_password = @password
    return false if stored_password.nil?

    return Crypto::Bcrypt::Password.new(stored_password).verify(password)
  end

  module PreferencesConverter
    def self.from_rs(rs)
      begin
        Preferences.from_json(rs.read(String))
      rescue ex
        Preferences.from_json("{}")
      end
    end
  end
end
