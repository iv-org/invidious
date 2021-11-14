macro error_template(*args)
  error_template_helper(env, locale, {{*args}})
end

def github_details(summary : String, content : String)
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

def error_template_helper(env : HTTP::Server::Context, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, exception : Exception)
  if exception.is_a?(InfoException)
    return error_template_helper(env, locale, status_code, exception.message || "")
  end
  env.response.content_type = "text/html"
  env.response.status_code = status_code
  issue_template = %(Title: `#{exception.message} (#{exception.class})`)
  issue_template += %(\nDate: `#{Time::Format::ISO_8601_DATE_TIME.format(Time.utc)}`)
  issue_template += %(\nRoute: `#{env.request.resource}`)
  issue_template += %(\nVersion: `#{SOFTWARE["version"]} @ #{SOFTWARE["branch"]}`)
  # issue_template += github_details("Preferences", env.get("preferences").as(Preferences).to_pretty_json)
  issue_template += github_details("Backtrace", exception.inspect_with_backtrace)
  error_message = <<-END_HTML
    Looks like you've found a bug in Invidious. Please open a new issue
    <a href="https://github.com/iv-org/invidious/issues">on GitHub</a>
    and include the following text in your message:
    <pre style="padding: 20px; background: rgba(0, 0, 0, 0.12345);">#{issue_template}</pre>
  END_HTML

  next_steps = error_redirect_helper(env, locale)

  return templated "error"
end

def error_template_helper(env : HTTP::Server::Context, locale : Hash(String, JSON::Any) | Nil, status_code : Int32, message : String)
  env.response.content_type = "text/html"
  env.response.status_code = status_code
  error_message = translate(locale, message)
  next_steps = error_redirect_helper(env, locale)
  return templated "error"
end

def error_redirect_helper(env : HTTP::Server::Context, locale : Hash(String, JSON::Any) | Nil)
  request_path = env.request.path

  if request_path.starts_with?("/search") || request_path.starts_with?("/watch") ||
     request_path.starts_with?("/channel") || request_path.starts_with?("/playlist?list=PL")
    next_steps_text = translate(locale, "next_steps_error_message")
    refresh = translate(locale, "next_steps_error_message_refresh")
    go_to_youtube = translate(locale, "next_steps_error_message_go_to_youtube")
    switch_instance = translate(locale, "Switch Invidious Instance")

    return <<-END_HTML
      <p style="margin-bottom: 4px;">#{next_steps_text}</p>
      <ul>
        <li>
          <a href="#{env.request.resource}">#{refresh}</a>
        </li>
        <li>
          <a href="/redirect?referer=#{env.get("current_page")}">#{switch_instance}</a>
        </li>
        <li>
          <a href="https://youtube.com#{env.request.resource}">#{go_to_youtube}</a>
        </li>
      </ul>
    END_HTML
  else
    return ""
  end
end
