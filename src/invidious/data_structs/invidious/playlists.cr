module InvidiousStructs
  # Converter to parse a Invidious privacy type string to enum
  module PlaylistPrivacyConverter
    def self.from_rs(rs)
      return PlaylistPrivacy.parse(String.new(rs.read(Slice(UInt8))))
    end
  end

  struct Playlist
    include DB::Serializable

    property title : String
    property id : String
    property author : String
    property description : String = ""
    property video_count : Int32
    property created : Time
    property updated : Time

    @[DB::Field(converter: InvidiousStructs::PlaylistPrivacyConverter)]
    property privacy : PlaylistPrivacy = PlaylistPrivacy::Private
    property index : Array(Int64)

    @[DB::Field(ignore: true)]
    property thumbnail_id : String?

    def to_json(offset, locale, json : JSON::Builder, video_id : String? = nil)
      json.object do
        json.field "type", "invidiousPlaylist"
        json.field "title", self.title
        json.field "playlistId", self.id

        json.field "author", self.author
        json.field "authorId", self.ucid
        json.field "authorUrl", nil
        json.field "authorThumbnails", [] of String

        json.field "description", html_to_content(self.description_html)
        json.field "descriptionHtml", self.description_html
        json.field "videoCount", self.video_count

        json.field "viewCount", self.views
        json.field "updated", self.updated.to_unix
        json.field "isListed", self.privacy.public?

        json.field "videos" do
          json.array do
            if !offset || offset == 0
              index = PG_DB.query_one?("SELECT index FROM playlist_videos WHERE plid = $1 AND id = $2 LIMIT 1", self.id, video_id, as: Int64)
              offset = self.index.index(index) || 0
            end

            videos = get_playlist_videos(PG_DB, self, offset: offset, locale: locale, video_id: video_id)
            videos.each_with_index do |video, index|
              video.to_json(locale, json, offset + index)
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

    def thumbnail
      @thumbnail_id ||= PG_DB.query_one?("SELECT id FROM playlist_videos WHERE plid = $1 ORDER BY array_position($2, index) LIMIT 1", self.id, self.index, as: String) || "-----------"
      "/vi/#{@thumbnail_id}/mqdefault.jpg"
    end

    def author_thumbnail
      nil
    end

    def ucid
      nil
    end

    def views
      0_i64
    end

    def description_html
      HTML.escape(self.description).gsub("\n", "<br>")
    end
  end
end
