struct CompilationVideo
  include DB::Serializable

  property title : String
  property id : String
  property author : String
  property ucid : String
  property length_seconds : Int32
  property starting_timestamp_seconds : Int32
  property ending_timestamp_seconds : Int32
  property published : Time
  property compid : String
  property index : Int64
  property order_index : Int32

  def to_xml(xml : XML::Builder)
    xml.element("entry") do
      xml.element("id") { xml.text "yt:video:#{self.id}" }
      xml.element("yt:videoId") { xml.text self.id }
      xml.element("yt:channelId") { xml.text self.ucid }
      xml.element("title") { xml.text self.title }
      xml.element("orderIndex") { xml.text self.order_index }
      xml.element("link", rel: "alternate", href: "#{HOST_URL}/watch?v=#{self.id}")

      xml.element("author") do
        xml.element("name") { xml.text self.author }
        xml.element("uri") { xml.text "#{HOST_URL}/channel/#{self.ucid}" }
      end

      xml.element("content", type: "xhtml") do
        xml.element("div", xmlns: "http://www.w3.org/1999/xhtml") do
          xml.element("a", href: "#{HOST_URL}/watch?v=#{self.id}") do
            xml.element("img", src: "#{HOST_URL}/vi/#{self.id}/mqdefault.jpg")
          end
        end
      end

      xml.element("published") { xml.text self.published.to_s("%Y-%m-%dT%H:%M:%S%:z") }

      xml.element("media:group") do
        xml.element("media:title") { xml.text self.title }
        xml.element("media:thumbnail", url: "#{HOST_URL}/vi/#{self.id}/mqdefault.jpg",
          width: "320", height: "180")
      end
    end
  end

  def to_xml(_xml : Nil = nil)
    XML.build { |xml| to_xml(xml) }
  end

  def to_json(json : JSON::Builder, index : Int32? = nil)
    json.object do
      json.field "title", self.title
      json.field "videoId", self.id

      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", "/channel/#{self.ucid}"

      json.field "videoThumbnails" do
        Invidious::JSONify::APIv1.thumbnails(json, self.id)
      end

      if index
        json.field "index", index
        json.field "indexId", self.index.to_u64.to_s(16).upcase
      else
        json.field "index", self.index
      end

      json.field "orderIndex", self.order_index
      json.field "lengthSeconds", self.length_seconds
      json.field "startingTimestampSeconds", self.starting_timestamp_seconds
      json.field "endingTimestampSeconds", self.ending_timestamp_seconds
    end
  end

  def to_json(_json : Nil, index : Int32? = nil)
    JSON.build { |json| to_json(json, index: index) }
  end
end

struct Compilation
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
  property first_video_id : String
  property first_video_starting_timestamp_seconds : Int32
  property first_video_ending_timestamp_seconds : Int32

  def to_json(offset, json : JSON::Builder, video_id : String? = nil)
    json.object do
      json.field "type", "compilation"
      json.field "title", self.title
      json.field "compilationId", self.id
      json.field "compilationThumbnail", self.thumbnail

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

      json.field "videos" do
        json.array do
          videos = get_compilation_videos(self, offset: offset, video_id: video_id)
          videos.each do |video|
            video.to_json(json)
          end
        end
      end
    end
  end

  def to_json(offset, _json : Nil = nil, video_id : String? = nil)
    JSON.build do |json|
      to_json(offset, json, video_id: video_id)
    end
  end

  def privacy
    CompilationPrivacy::Unlisted
  end
end

enum CompilationPrivacy
  Unlisted = 0
  Private  = 1
end

struct InvidiousCompilation
  include DB::Serializable

  property title : String
  property id : String
  property author : String
  property description : String = ""
  property video_count : Int32
  property created : Time
  property updated : Time

  @[DB::Field(converter: InvidiousCompilation::CompilationPrivacyConverter)]
  property privacy : CompilationPrivacy = CompilationPrivacy::Private
  property index : Array(Int64)
  property first_video_id : String
  property first_video_starting_timestamp_seconds : Int32
  property first_video_ending_timestamp_seconds : Int32

  @[DB::Field(ignore: true)]
  property thumbnail_id : String?

  module CompilationPrivacyConverter
    def self.from_rs(rs)
      return CompilationPrivacy.parse(String.new(rs.read(Slice(UInt8))))
    end
  end

  def to_json(offset, json : JSON::Builder, video_id : String? = nil)
    json.object do
      json.field "type", "invidiousCompilation"
      json.field "title", self.title
      json.field "compilationId", self.id

      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", nil
      json.field "authorThumbnails", [] of String

      json.field "description", html_to_content(self.description_html)
      json.field "descriptionHtml", self.description_html
      json.field "videoCount", self.video_count

      json.field "viewCount", self.views
      json.field "updated", self.updated.to_unix

      json.field "videos" do
        json.array do
          if (!offset || offset == 0) && !video_id.nil?
            index = Invidious::Database::CompilationVideos.select_index(self.id, video_id)
            offset = self.index.index(index) || 0
          end

          videos = get_compilation_videos(self, offset: offset, video_id: video_id)
          videos.each_with_index do |video, idx|
            video.to_json(json, offset + idx)
          end
        end
      end
    end
  end

  def to_json(offset, _json : Nil = nil, video_id : String? = nil)
    JSON.build do |json|
      to_json(offset, json, video_id: video_id)
    end
  end

  def thumbnail
    # TODO: Get compilation thumbnail from compilation data rather than first video
    @thumbnail_id ||= Invidious::Database::CompilationVideos.select_one_id(self.id, self.index) || "-----------"
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
    HTML.escape(self.description)
  end
end

def create_compilation(title, privacy, user)
  compid = "IVCMP#{Random::Secure.urlsafe_base64(24)[0, 31]}"

  compilation = InvidiousCompilation.new({
    title:                                  title.byte_slice(0, 150),
    id:                                     compid,
    author:                                 user.email,
    description:                            "", # Max 5000 characters
    video_count:                            0,
    created:                                Time.utc,
    updated:                                Time.utc,
    privacy:                                privacy,
    index:                                  [] of Int64,
    first_video_id:                         "",
    first_video_starting_timestamp_seconds: 0,
    first_video_ending_timestamp_seconds:   0,
  })

  Invidious::Database::Compilations.insert(compilation)

  return compilation
end

def subscribe_compilation(user, compilation)
  compilation = InvidiousCompilation.new({
    title:                                  compilation.title.byte_slice(0, 150),
    id:                                     compilation.id,
    author:                                 user.email,
    description:                            "", # Max 5000 characters
    video_count:                            compilation.video_count,
    created:                                Time.utc,
    updated:                                compilation.updated,
    privacy:                                CompilationPrivacy::Private,
    index:                                  [] of Int64,
    first_video_id:                         "",
    first_video_starting_timestamp_seconds: 0,
    first_video_ending_timestamp_seconds:   0,
  })

  Invidious::Database::Compilations.insert(compilation)

  return compilation
end

def produce_compilation_continuation(id, index)
  if id.starts_with? "UC"
    id = "UU" + id.lchop("UC")
  end
  compid = "VL" + id

  # Emulate a "request counter" increment, to make perfectly valid
  # ctokens, even if at the time of writing, it's ignored by youtube.
  request_count = (index / 100).to_i64 || 1_i64

  data = {"1:varint" => index.to_i64}
    .try { |i| Protodec::Any.cast_json(i) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i, padding: false) }

  object = {
    "80226972:embedded" => {
      "2:string" => plid,
      "3:base64" => {
        "1:varint"     => request_count,
        "15:string"    => "PT:#{data}",
        "104:embedded" => {"1:0:varint" => 0_i64},
      },
      "35:string" => id,
    },
  }

  continuation = object.try { |i| Protodec::Any.cast_json(i) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return continuation
end

def get_compilation(compid : String)
  if compilation = Invidious::Database::Compilations.select(id: compid)
    update_first_video_params(compid)
    return compilation
  else
    raise NotFoundException.new("Compilation does not exist.")
  end
end

def update_first_video_params(compid : String)
  if compilation = Invidious::Database::Compilations.select(id: compid)
    compilation_index_array = compilation.index
    if (compilation_index_array.size > 0)
      first_index = compilation_index_array[0]
      first_id = Invidious::Database::CompilationVideos.select_id_from_index(first_index)
      if !first_id.nil?
        timestamps = Invidious::Database::CompilationVideos.select_timestamps(compid, first_id)
        if (!timestamps.nil?)
          starting_timestamp_seconds = timestamps[0]
          ending_timestamp_seconds = timestamps[1]
          Invidious::Database::Compilations.update_first_video_params(compid, first_id, starting_timestamp_seconds, ending_timestamp_seconds)
        end
      end
    end
  else
    raise NotFoundException.new("Compilation does not exist.")
  end
end

def get_compilation_videos(compilation : InvidiousCompilation | Compilation, offset : Int32, video_id = nil)
  # Show empty compilation if requested page is out of range
  # (e.g, when a new compilation has been created, offset will be negative)
  if offset >= compilation.video_count || offset < 0
    return [] of CompilationVideo
  end

  if compilation.is_a? InvidiousCompilation
    Invidious::Database::CompilationVideos.select(compilation.id, compilation.index, offset, limit: 100)
  else
    if video_id
      initial_data = YoutubeAPI.next({
        "videoId"       => video_id,
        "compilationId" => compilation.id,
      })
      offset = initial_data.dig?("contents", "twoColumnWatchNextResults", "compilation", "compilation", "currentIndex").try &.as_i || offset
    end

    videos = [] of CompilationVideo

    until videos.size >= 200 || videos.size == compilation.video_count || offset >= compilation.video_count
      # 100 videos per request
      ctoken = produce_compilation_continuation(compilation.id, offset)
      initial_data = YoutubeAPI.browse(ctoken)
      videos += extract_compilation_videos(initial_data)

      offset += 100
    end

    return videos
  end
end

def extract_compilation_videos(initial_data : Hash(String, JSON::Any))
  videos = [] of CompilationVideo

  if initial_data["contents"]?
    tabs = initial_data["contents"]["twoColumnBrowseResultsRenderer"]["tabs"]
    tabs_renderer = tabs.as_a.select(&.["tabRenderer"]["selected"]?.try &.as_bool)[0]["tabRenderer"]

    # Watch out the two versions, with and without "s"
    if tabs_renderer["contents"]? || tabs_renderer["content"]?
      # Initial compilation data
      tabs_contents = tabs_renderer.["contents"]? || tabs_renderer.["content"]

      list_renderer = tabs_contents.["sectionListRenderer"]["contents"][0]
      item_renderer = list_renderer.["itemSectionRenderer"]["contents"][0]
      contents = item_renderer.["compilationVideoListRenderer"]["contents"].as_a
    else
      # Continuation data
      contents = initial_data["onResponseReceivedActions"][0]?
        .try &.["appendContinuationItemsAction"]["continuationItems"].as_a
    end
  else
    contents = initial_data["response"]?.try &.["continuationContents"]["compilationVideoListContinuation"]["contents"].as_a
  end

  contents.try &.each do |item|
    if i = item["compilationVideoRenderer"]?
      video_id = i["navigationEndpoint"]["watchEndpoint"]["videoId"].as_s
      compid = i["navigationEndpoint"]["watchEndpoint"]["compilationId"].as_s
      index = i["navigationEndpoint"]["watchEndpoint"]["index"].as_i64

      title = i["title"].try { |t| t["simpleText"]? || t["runs"]?.try &.[0]["text"]? }.try &.as_s || ""
      author = i["shortBylineText"]?.try &.["runs"][0]["text"].as_s || ""
      ucid = i["shortBylineText"]?.try &.["runs"][0]["navigationEndpoint"]["browseEndpoint"]["browseId"].as_s || ""
      length_seconds = i["lengthSeconds"]?.try &.as_s.to_i
      live = false

      if !length_seconds
        live = true
        length_seconds = 0
      end

      videos << CompilationVideo.new({
        title:                      title,
        id:                         video_id,
        author:                     author,
        ucid:                       ucid,
        length_seconds:             length_seconds,
        starting_timestamp_seconds: starting_timestamp_seconds,
        ending_timestamp_seconds:   ending_timestamp_seconds,
        published:                  Time.utc,
        compid:                     compid,
        index:                      index,
        order_index:                order_index,
      })
    end
  end

  return videos
end

def template_compilation(compilation)
  html = <<-END_HTML
  <h3>
    <a href="/compilation?comp=#{compilation["compilationId"]}">
      #{compilation["title"]}
    </a>
  </h3>
  <div class="pure-menu pure-menu-scrollable compilation-restricted">
    <ol class="pure-menu-list">
  END_HTML

  compilation["videos"].as_a.each do |video|
    html += <<-END_HTML
      <li class="pure-menu-item" id="#{video["videoId"]}">
        <a href="/watch?v=#{video["videoId"]}&comp=#{compilation["compilationId"]}&index=#{video["index"]}">
          <div class="thumbnail">
              <img loading="lazy" class="thumbnail" src="/vi/#{video["videoId"]}/mqdefault.jpg" alt="" />
              <p class="length">#{recode_length_seconds(video["lengthSeconds"].as_i)}</p>
          </div>
          <p style="width:100%">#{video["title"]}</p>
          <p>
            <b style="width:100%">#{video["author"]}</b>
          </p>
        </a>
      </li>
    END_HTML
  end

  html += <<-END_HTML
    </ol>
  </div>
  <hr>
  END_HTML

  html
end
