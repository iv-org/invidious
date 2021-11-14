macro error_json(*args)
  error_json_helper(env, locale, {{*args}})
end

def error_json_helper(env : HTTP::Server::Context, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, exception : Exception, additional_fields : Hash(String, Object) | Nil)
  if exception.is_a?(InfoException)
    return error_json_helper(env, locale, status_code, exception.message || "", additional_fields)
  end
  env.response.content_type = "application/json"
  env.response.status_code = status_code
  error_message = {"error" => exception.message, "errorBacktrace" => exception.inspect_with_backtrace}
  if additional_fields
    error_message = error_message.merge(additional_fields)
  end
  return error_message.to_json
end

def error_json_helper(env : HTTP::Server::Context, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, exception : Exception)
  return error_json_helper(env, locale, status_code, exception, nil)
end

def error_json_helper(env : HTTP::Server::Context, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, message : String, additional_fields : Hash(String, Object) | Nil)
  env.response.content_type = "application/json"
  env.response.status_code = status_code
  error_message = {"error" => message}
  if additional_fields
    error_message = error_message.merge(additional_fields)
  end
  return error_message.to_json
end

def error_json_helper(env : HTTP::Server::Context, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, message : String)
  error_json_helper(env, locale, status_code, message, nil)
end
