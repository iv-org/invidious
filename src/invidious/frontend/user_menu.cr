module Invidious::Frontend::UserMenu
  extend self

  # -------------------
  #  Menu items
  # -------------------

  enum UserContentMenu
    Subscriptions
    WatchHistory
    Playlists
  end

  enum UserAccountMenu
    Preferences
    Account
    ImportExport
    LogOut
  end

  private alias UserMenuItem = UserContentMenu | UserAccountMenu

  # -------------------
  #  HTML templates
  # -------------------

  # Generates the following menu:
  #
  # ```
  # <div class="user-menu"><ul>
  #   <li class="user-menu-tab"><a href="#">Subscriptions</a></li>
  #   <li class="user-menu-tab"><a href="#">Watch history</a></li>
  #   <li class="user-menu-tab"><a href="#">Playlists</a></li>
  # </ul></div>
  #
  # <div class="user-menu"><ul>
  #   <li class="user-menu-tab"><p>Preferences</p></li>
  #   <li class="user-menu-tab"><a href="#">Account</a></li>
  #   <li class="user-menu-tab"><a href="#">Import &amp; Export</a></li>
  #   <li class="user-menu-tab"><p>Log Out</p></li>
  # </ul></div>
  # ```
  #
  # The selected entry will have the "selected" class.
  #
  def make_menu(env : HTTP::Server::Context, selected_item : UserMenuItem) : String
    # A capacity of 1500 is enough to store the HTML (empty)
    # plus the URLs with parameters and the translated text.
    str_builder = String::Builder.new(1500)

    # TODO: Get variables from HTTP env
    locale = env.get("preferences").as(Preferences).locale
    params = nil

    # Start of menu #1
    str_builder << <<-HTML
    <div class="user-menu"><ul>
    HTML

    # Menu items for the 1st menu
    UserContentMenu.each do |menu_item|
      case menu_item
      when .subscriptions? then url = "/subscription_manager"
      when .watch_history? then url = "/feed/history"
      when .playlists?     then url = "/user/subscription_manager"
      end

      url += "?" + params if params

      text = HTML.escape(translate(locale, "user_menu_item_" + menu_item.to_s.underscore))

      if menu_item == selected_item
        str_builder << "\t<li class=\"user-menu-tab selected\"><p>#{text}</p></li>\n"
      else
        str_builder << "\t<li class=\"user-menu-tab\"><a href=\"#{url}\">#{text}</a></li>\n"
      end
    end

    # End of menu #1, start of menu #2
    str_builder << <<-HTML
    </ul></div>
    <div class="user-menu"><ul>
    HTML

    # Menu items for the 2nd menu
    UserAccountMenu.each do |menu_item|
      case menu_item
      when .preferences?   then url = "/preferences"
      when .account?       then url = "/" # TODO
      when .import_export? then url = "/data_control"
      when .log_out?       then url = "/log_out"
      end

      url += "?" + params if params

      text = HTML.escape(translate(locale, "user_menu_item_" + menu_item.to_s.underscore))

      if menu_item == selected_item
        str_builder << "\t<li class=\"user-menu-tab selected\"><p>#{text}</p></li>\n"
      else
        str_builder << "\t<li class=\"user-menu-tab\"><a href=\"#{url}\">#{text}</a></li>\n"
      end
    end

    # End of menu #2
    str_builder << <<-HTML
    </ul></div>
    HTML

    return str_builder.to_s
  end
end
