struct Invidious::User
  module Export
    extend self

    struct NewPipe
      include JSON::Serializable

      # Hardcoded NewPipe values that are needed
      # so NewPipe can import the JSON.
      private APP_VERSION     = "0.29.0"
      private APP_VERSION_INT = 1014
      private YT_SERVICE_ID   =    0

      getter subscriptions : Array(Subscription)

      struct Subscription
        include JSON::Serializable

        getter service_id : Int32 = YT_SERVICE_ID
        getter url : String
        getter name : String

        def initialize(channel : InvidiousChannel)
          @url = "https://www.youtube.com/channel/" + channel.id
          @name = channel.author
        end
      end

      getter app_version : String = APP_VERSION
      getter app_version_int : Int32 = APP_VERSION_INT

      def initialize(channels : Array(InvidiousChannel))
        @subscriptions = channels.map { |channel| Subscription.new(channel) }
      end
    end

    def to_newpipe(subscriptions : Array(InvidiousChannel))
      NewPipe.new(subscriptions).to_json
    end

    struct Invidious
      include JSON::Serializable

      getter subscriptions : Array(String)
      getter watch_history : Array(String)
      getter preferences : Preferences
      getter playlists : Array(Playlist)

      struct Playlist
        include JSON::Serializable

        getter title : String
        getter description : String
        getter privacy : String
        getter videos : Array(String)

        def initialize(playlist : InvidiousPlaylist)
          @title = playlist.title
          @description = ::Invidious::Helpers.html_to_content(playlist.description_html)
          @privacy = playlist.privacy.to_s
          @videos = ::Invidious::Database::PlaylistVideos.select_ids(
            playlist.id, playlist.index, limit: CONFIG.playlist_length_limit
          )
        end
      end

      def initialize(user : User)
        @subscriptions = user.subscriptions
        @watch_history = user.watched
        @preferences = user.preferences
        @playlists = ::Invidious::Database::Playlists.select_like_iv(user.email)
          .map { |playlist| Playlist.new(playlist) }
      end
    end

    def to_invidious(user : User)
      Invidious.new(user).to_json
    end

    def to_freetube_opml(subscriptions : Array(InvidiousChannel))
      export = XML.build do |xml|
        xml.element("opml", version: "1.1") do
          xml.element("body") do
            title = "Invidious Subscriptions"

            xml.element("outline", text: title, title: title) do
              subscriptions.each do |channel|
                xml_url = "https://www.youtube.com/feeds/videos.xml?channel_id=#{channel.id}"

                xml.element("outline", text: channel.author, title: channel.author,
                  "type": "rss", xmlUrl: xml_url)
              end
            end
          end
        end
      end

      export.gsub(%(<?xml version="1.0"?>\n), "")
    end
  end # module
end
