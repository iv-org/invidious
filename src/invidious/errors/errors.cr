macro error_template(*args)
  generic_error_template_helper(env, locale, {{*args}})
end

def github_details_backtrace(summary : String, content : String)
  details = %(\n<details>)
  details += %(\n<summary>#{summary}</summary>)
  details += %(\n<p>)
  details += %(\n   \n```\n)
  details += content.strip
  details += %(\n```)
  details += %(\n</p>)
  details += %(\n</details>)
  return HTML.escape(details)
end

def generic_error_template_helper(env : HTTP::Server::Context, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, exception : Exception)
  # Custom error routing
  if exception.is_a?(InfoException)
    return generic_error_template_helper(env, locale, status_code, exception.message || "")
  elsif exception.is_a? InitialInnerTubeParseException
    return exception.error_template_helper(env, locale)
  end

  env.response.content_type = "text/html"
  env.response.status_code = status_code

  # HTML rendering.
  # We're only keeping the github details creation in here in order to
  # avoid manually writing escaped HTML.
  backtrace = github_details_backtrace("Backtrace", exception.inspect_with_backtrace)
  error_message = rendered "error_pages/generic"

  return templated "error_pages/generic_wrapper"
end

# Handles InfoExceptions
#
# This is mostly for backward compatibility with the `error_template(401, "Message")` types
def generic_error_template_helper(env : HTTP::Server::Context, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, message : String)
  env.response.content_type = "text/html"
  env.response.status_code = status_code
  error_message = translate(locale, message)
  return templated "error_pages/generic_wrapper"
end
