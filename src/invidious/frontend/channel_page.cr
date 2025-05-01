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
          # Video tab doesn't have the last path component
          url = tab.videos? ? base_url : "#{base_url}/#{tab_name}"
          selected_class = tab == selected_tab ? "selected" : ""

          str << %(<li class=") << selected_class << %(">\n)
          str << %(\t<a href=") << url << %(">)
          str << translate(locale, "channel_tab_#{tab_name}_label")
          str << "</a>\n"
          str << "</li>"
        end
      end
    end
  end
end
