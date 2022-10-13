module Invidious::Frontend::LoginRegister
  extend self

  # HTML form input template
  #
  # `id` defines the CSS `id` attribute, as well as the localized label text.
  # `type` defines the type of input (text, password, etc...)
  private macro text_input(id, type)
    str << %(\t\t\t<div class="pure-control-group">\n)
    str << "\t\t\t\t<label for='{{id}}'>"
    str << translate(locale, "login_page_{{id}}_label")
    str << "</label><input type='{{type}}' id='{{id}}'>\n"
    str << "\t\t\t</div>\n"
  end

  # Submit button template
  #
  # `variant` provided defines the CSS class name, as well
  # as the associated localized text string.
  private macro submit_button(variant)
    str << %(\t<div class="pure-controls {{variant}}-submit-button">\n)
    str << %(\t\t<button type='submit' class="pure-button pure-button-primary">)
    str << translate(locale, "login_page_{{variant}}_button")
    str << "</button>\n"
    str << "\t</div>\n"
  end

  # Generate the log-in form's HTML
  def gen_login_form(
    env : HTTP::Server::Context,
    account_type : String = "invidious",
    captcha : User::Captcha? = nil
  ) : String
    locale = env.get("preferences").as(Preferences).locale

    # Create the parameters for the form URL
    params = HTTP::Params.new
    params["type"] = account_type

    if referer = env.get?("referer").try &.as(String)
      params["referer"] = referer
    end

    url = URI.new(path: "/login", query: params)

    return String.build(1200) do |str|
      # Begin log-in form
      str << %(\t<form class="pure-form" method='post' action=") << url << %(">)

      # Form content
      case account_type
      when "invidious"
        # Text inputs
        str << %(\t\t<div class="username-pass-fields">)
        str << %(<fieldset class="pure-form-aligned">\n)

        text_input(username, text)
        text_input(password, password)

        str << "\t\t</fieldset></div>\n"

        # Captcha, if required
        if !captcha.nil? && !captcha.type.none?
          str << rendered "components/captcha"
        end
      end

      # End of log-in form
      str << "\t</form>\n"

      submit_button(login)

      # Prompt for the register page (we reuse the form's
      # uri object for simplicity sake)
      url.path = "/register"

      str << "\t<p>"
      str << translate(locale, "login_page_goto_register_prompt", url.to_s)
      str << "</p>\n"
    end
  end

  # Generate the registration form's HTML
  def gen_register_form(
    env : HTTP::Server::Context,
    captcha : User::Captcha?
  ) : String
    locale = env.get("preferences").as(Preferences).locale

    # Create the parameters for the form URL
    params = HTTP::Params.new
    if referer = env.get?("referer").try &.as(String)
      params["referer"] = referer
    end

    url = URI.new(path: "/register", query: params)

    return String.build(1200) do |str|
      # Begin registration form
      str << %(\t<form class="pure-form" method='post' action=") << url << %(">)

      # Text inputs
      str << %(\t\t<div class="username-pass-fields">)
      str << %(<fieldset class="pure-form-aligned">\n)

      text_input(username, text)
      str << "<br/>"

      text_input(password, password)
      text_input(confirm, password)

      str << "\t\t</fieldset></div>\n"

      # Captcha, if required
      if !captcha.nil? && !captcha.type.none?
        str << rendered "components/captcha"
      end

      # End of registration form
      str << "\t</form>\n"

      submit_button(register)

      # Prompt for the login page (we reuse the form's
      # uri object for simplicity sake)
      url.path = "/login"

      str << "\t<p>"
      str << translate(locale, "login_page_goto_login_prompt", url.to_s)
      str << "</p>\n"

      str << "</div>"
    end
  end
end
