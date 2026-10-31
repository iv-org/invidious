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

    def to_invidious(user : User)
      playlists = Invidious::Database::Playlists.select_like_iv(user.email)

      return JSON.build do |json|
        json.object do
          json.field "subscriptions", user.subscriptions
          json.field "watch_history", user.watched
          json.field "preferences", user.preferences
          json.field "playlists" do
            json.array do
              playlists.each do |playlist|
                json.object do
                  json.field "title", playlist.title
                  json.field "description", Invidious::Helpers.html_to_content(playlist.description_html)
                  json.field "privacy", playlist.privacy.to_s
                  json.field "videos" do
                    json.array do
                      Invidious::Database::PlaylistVideos.select_ids(playlist.id, playlist.index, limit: CONFIG.playlist_length_limit).each do |video_id|
                        json.string video_id
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end # module
end
