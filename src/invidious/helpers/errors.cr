# -------------------
#  Issue template
# -------------------

macro error_template(*args)
  error_template_helper(env, {{args.splat}})
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

def error_template_helper(env : HTTP::Server::Context, status_code : Int32, exception : Exception)
  if exception.is_a?(InfoException)
    return error_template_helper(env, status_code, exception.message || "")
  end

  locale = env.get("preferences").as(Preferences).locale

  env.response.content_type = "text/html"
  env.response.status_code = status_code

  issue_title = "#{exception.message} (#{exception.class})"

  issue_template = <<-TEXT
  Title: `#{HTML.escape(issue_title)}`
  Date: `#{Time::Format::ISO_8601_DATE_TIME.format(Time.utc)}`
  Route: `#{HTML.escape(env.request.resource)}`
  Version: `#{SOFTWARE["version"]} @ #{SOFTWARE["branch"]}`

  TEXT

  issue_template += github_details("Backtrace", exception.inspect_with_backtrace)

  # URLs for the error message below
  url_faq = "https://github.com/iv-org/documentation/blob/master/docs/faq.md"
  url_search_issues = "https://github.com/iv-org/invidious/issues"
  url_search_issues += "?q=is:issue+is:open+"
  url_search_issues += URI.encode_www_form("[Bug] #{issue_title}")

  url_switch = "https://redirect.invidious.io" + env.request.resource

  url_new_issue = "https://github.com/iv-org/invidious/issues/new"
  url_new_issue += "?labels=bug&template=bug_report.md&title="
  url_new_issue += URI.encode_www_form("[Bug] " + issue_title)

  error_message = <<-END_HTML
    <div class="error_message">
      <h2>#{translate(locale, "crash_page_you_found_a_bug")}</h2>
      <br/><br/>

      <p><b>#{translate(locale, "crash_page_before_reporting")}</b></p>
      <ul>
        <li>#{translate(locale, "crash_page_refresh", env.request.resource)}</li>
        <li>#{translate(locale, "crash_page_switch_instance", url_switch)}</li>
        <li>#{translate(locale, "crash_page_read_the_faq", url_faq)}</li>
        <li>#{translate(locale, "crash_page_search_issue", url_search_issues)}</li>
      </ul>

      <br/>
      <p>#{translate(locale, "crash_page_report_issue", url_new_issue)}</p>

      <!-- TODO: Add a "copy to clipboard" button -->
      <pre style="padding: 20px; background: rgba(0, 0, 0, 0.12345);">#{issue_template}</pre>
    </div>
  END_HTML

  return templated "error"
end

def error_template_helper(env : HTTP::Server::Context, status_code : Int32, message : String)
  env.response.content_type = "text/html"
  env.response.status_code = status_code

  locale = env.get("preferences").as(Preferences).locale

  error_message = <<-END_HTML
    <div class="error_message">
      <h2>#{translate(locale, "error_processing_data_youtube")}</h2>
      <p>#{translate(locale, message)}</p>
      #{error_redirect_helper(env)}
    </div>
  END_HTML

  return templated "error"
end

# -------------------
#  Atom feeds
# -------------------

macro error_atom(*args)
  error_atom_helper(env, {{args.splat}})
end

def error_atom_helper(env : HTTP::Server::Context, status_code : Int32, exception : Exception)
  if exception.is_a?(InfoException)
    return error_atom_helper(env, status_code, exception.message || "")
  end

  env.response.content_type = "application/atom+xml"
  env.response.status_code = status_code

  return "<error>#{exception.inspect_with_backtrace}</error>"
end

def error_atom_helper(env : HTTP::Server::Context, status_code : Int32, message : String)
  env.response.content_type = "application/atom+xml"
  env.response.status_code = status_code

  return "<error>#{message}</error>"
end

# -------------------
#  JSON
# -------------------

macro error_json(*args)
  error_json_helper(env, {{args.splat}})
end

def error_json_helper(
  env : HTTP::Server::Context,
  status_code : Int32,
  exception : Exception,
  additional_fields : Hash(String, Object) | Nil = nil
)
  if exception.is_a?(InfoException)
    return error_json_helper(env, status_code, exception.message || "", additional_fields)
  end

  env.response.content_type = "application/json"
  env.response.status_code = status_code

  error_message = {"error" => exception.message, "errorBacktrace" => exception.inspect_with_backtrace}

  if additional_fields
    error_message = error_message.merge(additional_fields)
  end

  return error_message.to_json
end

def error_json_helper(
  env : HTTP::Server::Context,
  status_code : Int32,
  message : String,
  additional_fields : Hash(String, Object) | Nil = nil
)
  env.response.content_type = "application/json"
  env.response.status_code = status_code

  error_message = {"error" => message}

  if additional_fields
    error_message = error_message.merge(additional_fields)
  end

  return error_message.to_json
end

# -------------------
#  Redirect
# -------------------

def error_redirect_helper(env : HTTP::Server::Context)
  request_path = env.request.path

  locale = env.get("preferences").as(Preferences).locale

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
          <a rel="noreferrer noopener" href="https://youtube.com#{env.request.resource}">#{go_to_youtube}</a>
        </li>
      </ul>
    END_HTML
  else
    return ""
  end
end
