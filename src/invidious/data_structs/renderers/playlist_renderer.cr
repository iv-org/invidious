module YTStructs
  alias PlaylistRendererVideo = NamedTuple(title: String, id: String, length_seconds: Int32)

  # Struct to represent an InnerTube `"PlaylistRenderer"`
  #
  # A gridPlaylistRenderer renders a playlist, that is located in a grid, to click on within the YouTube and Invidious UI.
  # It is **not** the playlist itself.
  #
  # See specs for example JSON response
  #
  # `PlaylistRenderer`s can be found almost everywhere on YouTube. In categories, search results, channels, etc.
  #
  struct PlaylistRenderer
    include DB::Serializable

    property title : String
    property id : String
    property author : String
    property ucid : String
    property video_count : Int32
    property videos : Array(PlaylistRendererVideo)
    property thumbnail : String?

    def to_json(locale, json : JSON::Builder)
      json.object do
        json.field "type", "playlist"
        json.field "title", self.title
        json.field "playlistId", self.id
        json.field "playlistThumbnail", self.thumbnail

        json.field "author", self.author
        json.field "authorId", self.ucid
        json.field "authorUrl", "/channel/#{self.ucid}"

        json.field "videoCount", self.video_count
        json.field "videos" do
          json.array do
            self.videos.each do |video|
              json.object do
                json.field "title", video.title
                json.field "videoId", video.id
                json.field "lengthSeconds", video.length_seconds

                json.field "videoThumbnails" do
                  generate_thumbnails(json, video.id)
                end
              end
            end
          end
        end
      end
    end

    def to_json(locale, json : JSON::Builder | Nil = nil)
      if json
        to_json(locale, json)
      else
        JSON.build do |json|
          to_json(locale, json)
        end
      end
    end
  end
end
