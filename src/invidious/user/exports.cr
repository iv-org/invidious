struct Invidious::User
  module Export
    extend self

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
                  json.field "description", html_to_content(playlist.description_html)
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
