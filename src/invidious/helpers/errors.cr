# InfoExceptions are for displaying information to the user.
#
# An InfoException might or might not indicate that something went wrong.
# Historically Invidious didn't differentiate between these two options, so to
# maintain previous functionality InfoExceptions do not print backtraces.
class InfoException < Exception
end

macro error_template(*args)
  error_template_helper(env, config, locale, {{*args}})
end

def error_template_helper(env : HTTP::Server::Context, config : Config, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, exception : Exception)
  if exception.is_a?(InfoException)
    return error_template_helper(env, config, locale, status_code, exception.message || "")
  end
  env.response.status_code = status_code
  issue_template = %(Date: `#{Time::Format::ISO_8601_DATE_TIME.format(Time.utc)}`)
  issue_template += %(\nRoute: `#{env.request.resource}`)
  issue_template += %(\nVersion: `#{SOFTWARE["version"]} @ #{SOFTWARE["branch"]}`)
  #issue_template += %(\nPreferences: ```#{env.get("preferences").as(Preferences).to_json}```)
  issue_template += %(\nBacktrace: \n```\n#{exception.inspect_with_backtrace}```)
  error_message = <<-END_HTML
    Looks like you've found a bug in Invidious. Please open a new issue
    <a href="https://github.com/iv-org/invidious/issues">on GitHub</a>
    and include the following text in your message:
    <pre style="padding: 20px; background: rgba(0, 0, 0, 0.12345);">#{issue_template}</pre>
  END_HTML
  return templated "error"
end

def error_template_helper(env : HTTP::Server::Context, config : Config, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, message : String)
  env.response.status_code = status_code
  error_message = translate(locale, message)
  return templated "error"
end

macro error_atom(*args)
  error_atom_helper(env, config, locale, {{*args}})
end

def error_atom_helper(env : HTTP::Server::Context, config : Config, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, exception : Exception)
  if exception.is_a?(InfoException)
    return error_atom_helper(env, config, locale, status_code, exception.message || "")
  end
  env.response.content_type = "application/atom+xml"
  env.response.status_code = status_code
  return "<error>#{exception.inspect_with_backtrace}</error>"
end

def error_atom_helper(env : HTTP::Server::Context, config : Config, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, message : String)
  env.response.content_type = "application/atom+xml"
  env.response.status_code = status_code
  return "<error>#{message}</error>"
end

macro error_json(*args)
  error_json_helper(env, config, locale, {{*args}})
end

def error_json_helper(env : HTTP::Server::Context, config : Config, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, exception : Exception, additional_fields : Hash(String, Object) | Nil)
  if exception.is_a?(InfoException)
    return error_json_helper(env, config, locale, status_code, exception.message || "", additional_fields)
  end
  env.response.content_type = "application/json"
  env.response.status_code = status_code
  error_message = {"error" => exception.message, "errorBacktrace" => exception.inspect_with_backtrace}
  if additional_fields
    error_message = error_message.merge(additional_fields)
  end
  return error_message.to_json
end

def error_json_helper(env : HTTP::Server::Context, config : Config, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, exception : Exception)
  return error_json_helper(env, config, locale, status_code, exception, nil)
end

def error_json_helper(env : HTTP::Server::Context, config : Config, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, message : String, additional_fields : Hash(String, Object) | Nil)
  env.response.content_type = "application/json"
  env.response.status_code = status_code
  error_message = {"error" => message}
  if additional_fields
    error_message = error_message.merge(additional_fields)
  end
  return error_message.to_json
end

def error_json_helper(env : HTTP::Server::Context, config : Config, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, message : String)
  error_json_helper(env, config, locale, status_code, message, nil)
end
