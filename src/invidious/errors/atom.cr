macro error_atom(*args)
  error_atom_helper(env, locale, {{*args}})
end

def error_atom_helper(env : HTTP::Server::Context, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, exception : Exception)
  if exception.is_a?(InfoException)
    return error_atom_helper(env, locale, status_code, exception.message || "")
  end
  env.response.content_type = "application/atom+xml"
  env.response.status_code = status_code
  return "<error>#{exception.inspect_with_backtrace}</error>"
end

def error_atom_helper(env : HTTP::Server::Context, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, message : String)
  env.response.content_type = "application/atom+xml"
  env.response.status_code = status_code
  return "<error>#{message}</error>"
end
