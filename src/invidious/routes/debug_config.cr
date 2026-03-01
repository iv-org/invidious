# Debug route to verify configuration is loaded correctly
# This can help diagnose issues with pages_enabled configuration

module Invidious::Routes::DebugConfig
  def self.show(env)
    # Only allow access to admins or in development mode
    if CONFIG.admins.empty? || (user = env.get? "user")
      admin_user = user.try &.as(User)
      if !admin_user || !CONFIG.admins.includes?(admin_user.email)
        return error_template(403, "Administrator privileges required")
      end
    else
      # If no user is logged in and admins are configured, deny access
      return error_template(403, "Administrator privileges required")
    end

    html = <<-HTML
    <!DOCTYPE html>
    <html>
    <head>
      <title>Configuration Debug - Invidious</title>
      <style>
        body { font-family: monospace; padding: 20px; }
        .enabled { color: green; }
        .disabled { color: red; }
        table { border-collapse: collapse; margin: 20px 0; }
        td, th { border: 1px solid #ccc; padding: 8px; text-align: left; }
        th { background: #f0f0f0; }
        pre { background: #f5f5f5; padding: 10px; overflow-x: auto; }
      </style>
    </head>
    <body>
      <h1>Invidious Configuration Debug</h1>

      <h2>Pages Configuration</h2>
      <table>
        <tr>
          <th>Page</th>
          <th>Status</th>
          <th>Configuration Value</th>
        </tr>
        <tr>
          <td>Popular</td>
          <td class="#{CONFIG.page_enabled?("popular") ? "enabled" : "disabled"}">
            #{CONFIG.page_enabled?("popular") ? "ENABLED" : "DISABLED"}
          </td>
          <td>#{CONFIG.pages_enabled.popular}</td>
        </tr>
        <tr>
          <td>Trending</td>
          <td class="#{CONFIG.page_enabled?("trending") ? "enabled" : "disabled"}">
            #{CONFIG.page_enabled?("trending") ? "ENABLED" : "DISABLED"}
          </td>
          <td>#{CONFIG.pages_enabled.trending}</td>
        </tr>
        <tr>
          <td>Search</td>
          <td class="#{CONFIG.page_enabled?("search") ? "enabled" : "disabled"}">
            #{CONFIG.page_enabled?("search") ? "ENABLED" : "DISABLED"}
          </td>
          <td>#{CONFIG.pages_enabled.search}</td>
        </tr>
      </table>

      <h2>Configuration Flags</h2>
      <table>
        <tr>
          <th>Flag</th>
          <th>Value</th>
        </tr>
        <tr>
          <td>pages_enabled_present</td>
          <td>#{CONFIG.pages_enabled_present}</td>
        </tr>
        <tr>
          <td>popular_enabled_present (deprecated)</td>
          <td>#{CONFIG.popular_enabled_present}</td>
        </tr>
        <tr>
          <td>popular_enabled (deprecated)</td>
          <td>#{CONFIG.popular_enabled}</td>
        </tr>
      </table>

      <h2>Blocked Routes</h2>
      <p>The following routes should be blocked based on current configuration:</p>
      <ul>
        #{!CONFIG.page_enabled?("popular") ? "<li>/feed/popular</li><li>/api/v1/popular</li>" : ""}
        #{!CONFIG.page_enabled?("trending") ? "<li>/feed/trending</li><li>/api/v1/trending</li>" : ""}
        #{!CONFIG.page_enabled?("search") ? "<li>/search</li><li>/api/v1/search</li>" : ""}
      </ul>

      <h2>Test Links</h2>
      <p>Click these links to verify they are properly blocked:</p>
      <ul>
        <li><a href="/feed/popular">/feed/popular</a> - #{CONFIG.page_enabled?("popular") ? "Should work" : "Should be blocked"}</li>
        <li><a href="/feed/trending">/feed/trending</a> - #{CONFIG.page_enabled?("trending") ? "Should work" : "Should be blocked"}</li>
        <li><a href="/search">/search</a> - #{CONFIG.page_enabled?("search") ? "Should work" : "Should be blocked"}</li>
      </ul>

      <h2>Raw Configuration</h2>
      <pre>pages_enabled: #{CONFIG.pages_enabled.inspect}</pre>

      <h2>Environment Check</h2>
      <pre>INVIDIOUS_CONFIG present: #{ENV.has_key?("INVIDIOUS_CONFIG")}</pre>
      <pre>INVIDIOUS_PAGES_ENABLED present: #{ENV.has_key?("INVIDIOUS_PAGES_ENABLED")}</pre>
    </body>
    </html>
    HTML

    env.response.content_type = "text/html"
    env.response.print html
  end
end