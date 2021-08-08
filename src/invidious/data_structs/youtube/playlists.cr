module YouTubeStructs
  struct Playlist
    include DB::Serializable

    property title : String
    property id : String
    property author : String
    property author_thumbnail : String
    property ucid : String
    property description : String
    property description_html : String
    property video_count : Int32
    property views : Int64
    property updated : Time
    property thumbnail : String?

    def to_json(offset, locale, json : JSON::Builder, video_id : String? = nil)
      json.object do
        json.field "type", "playlist"
        json.field "title", self.title
        json.field "playlistId", self.id
        json.field "playlistThumbnail", self.thumbnail

        json.field "author", self.author
        json.field "authorId", self.ucid
        json.field "authorUrl", "/channel/#{self.ucid}"

        json.field "authorThumbnails" do
          json.array do
            qualities = {32, 48, 76, 100, 176, 512}

            qualities.each do |quality|
              json.object do
                json.field "url", self.author_thumbnail.not_nil!.gsub(/=\d+/, "=s#{quality}")
                json.field "width", quality
                json.field "height", quality
              end
            end
          end
        end

        json.field "description", self.description
        json.field "descriptionHtml", self.description_html
        json.field "videoCount", self.video_count

        json.field "viewCount", self.views
        json.field "updated", self.updated.to_unix
        json.field "isListed", self.privacy.public?

        json.field "videos" do
          json.array do
            videos = get_playlist_videos(PG_DB, self, offset: offset, locale: locale, video_id: video_id)
            videos.each do |video|
              video.to_json(locale, json)
            end
          end
        end
      end
    end

    def to_json(offset, locale, json : JSON::Builder? = nil, video_id : String? = nil)
      if json
        to_json(offset, locale, json, video_id: video_id)
      else
        JSON.build do |json|
          to_json(offset, locale, json, video_id: video_id)
        end
      end
    end

    def privacy
      PlaylistPrivacy::Public
    end
  end
end
