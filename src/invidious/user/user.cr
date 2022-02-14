require "db"

struct Invidious::User
  include DB::Serializable

  property updated : Time
  property notifications : Array(String)
  property subscriptions : Array(String)
  property email : String

  @[DB::Field(converter: Invidious::User::PreferencesConverter)]
  property preferences : Preferences
  property password : String?
  property token : String
  property watched : Array(String)
  property feed_needs_update : Bool?

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
