require "./spec_helper"

class ContextWithPreferences < HTTP::Server::Context
  property preferences : Preferences?

  def get(key : String)
    return preferences if key == "preferences"

    super
  end

  def get?(key : String)
    return preferences if key == "preferences"

    super
  end

  def set(key : String, val : Preferences)
    if key == "preferences"
      self.preferences = val
    else
      super
    end
  end
end

def test_env(current_url : String, request_method : String = "GET", response : IO = String::Builder.new)
    con = ContextWithPreferences.new(
      HTTP::Request.new(request_method, current_url),
      HTTP::Server::Response.new(response),
    )
    con.preferences = Preferences.new(CONFIG.default_user_preferences.to_tuple)
    con
end
