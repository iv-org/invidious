module Invidious::Frontend::ChannelPage
  extend self

  enum TabsAvailable
    Videos
    Shorts
    Streams
    Podcasts
    Releases
    Playlists
    Community
    Channels
  end

  def generate_tabs_links(locale : String, channel : AboutChannel, selected_tab : TabsAvailable)
    return String.build(1500) do |str|
      base_url = "/channel/#{channel.ucid}"

      TabsAvailable.each do |tab|
        # Ignore playlists, as it is not supported for auto-generated channels yet
        next if (tab.playlists? && channel.auto_generated)

        tab_name = tab.to_s.downcase

        if channel.tabs.includes? tab_name
          str << %(<div class="pure-u-1 pure-md-1-3">\n)

          if tab == selected_tab
            str << "\t<b>"
            str << translate(locale, "channel_tab_#{tab_name}_label")
            str << "</b>\n"
          else
            # Video tab doesn't have the last path component
            url = tab.videos? ? base_url : "#{base_url}/#{tab_name}"

            str << %(\t<a href=") << url << %(">)
            str << translate(locale, "channel_tab_#{tab_name}_label")
            str << "</a>\n"
          end

          str << "</div>"
        end
      end
    end
  end
end
