struct PlaylistVideo
  def to_xml(host_url, auto_generated, xml : XML::Builder)
    xml.element("entry") do
      xml.element("id") { xml.text "yt:video:#{self.id}" }
      xml.element("yt:videoId") { xml.text self.id }
      xml.element("yt:channelId") { xml.text self.ucid }
      xml.element("title") { xml.text self.title }
      xml.element("link", rel: "alternate", href: "#{host_url}/watch?v=#{self.id}")

      xml.element("author") do
        if auto_generated
          xml.element("name") { xml.text self.author }
          xml.element("uri") { xml.text "#{host_url}/channel/#{self.ucid}" }
        else
          xml.element("name") { xml.text author }
          xml.element("uri") { xml.text "#{host_url}/channel/#{ucid}" }
        end
      end

      xml.element("content", type: "xhtml") do
        xml.element("div", xmlns: "http://www.w3.org/1999/xhtml") do
          xml.element("a", href: "#{host_url}/watch?v=#{self.id}") do
            xml.element("img", src: "#{host_url}/vi/#{self.id}/mqdefault.jpg")
          end
        end
      end

      xml.element("published") { xml.text self.published.to_s("%Y-%m-%dT%H:%M:%S%:z") }

      xml.element("media:group") do
        xml.element("media:title") { xml.text self.title }
        xml.element("media:thumbnail", url: "#{host_url}/vi/#{self.id}/mqdefault.jpg",
          width: "320", height: "180")
      end
    end
  end

  def to_xml(host_url, auto_generated, xml : XML::Builder? = nil)
    if xml
      to_xml(host_url, auto_generated, xml)
    else
      XML.build do |json|
        to_xml(host_url, auto_generated, xml)
      end
    end
  end

  def to_json(locale, config, kemal_config, json : JSON::Builder, index : Int32?)
    json.object do
      json.field "title", self.title
      json.field "videoId", self.id

      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", "/channel/#{self.ucid}"

      json.field "videoThumbnails" do
        generate_thumbnails(json, self.id, config, kemal_config)
      end

      if index
        json.field "index", index
        json.field "indexId", self.index.to_u64.to_s(16).upcase
      else
        json.field "index", self.index
      end

      json.field "lengthSeconds", self.length_seconds
    end
  end

  def to_json(locale, config, kemal_config, json : JSON::Builder? = nil, index : Int32? = nil)
    if json
      to_json(locale, config, kemal_config, json, index: index)
    else
      JSON.build do |json|
        to_json(locale, config, kemal_config, json, index: index)
      end
    end
  end

  db_mapping({
    title:          String,
    id:             String,
    author:         String,
    ucid:           String,
    length_seconds: Int32,
    published:      Time,
    plid:           String,
    index:          Int64,
    live_now:       Bool,
  })
end

struct Playlist
  def to_json(offset, locale, config, kemal_config, json : JSON::Builder, continuation : String? = nil)
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

      json.field "description", html_to_content(self.description_html)
      json.field "descriptionHtml", self.description_html
      json.field "videoCount", self.video_count

      json.field "viewCount", self.views
      json.field "updated", self.updated.to_unix
      json.field "isListed", self.privacy.public?

      json.field "videos" do
        json.array do
          videos = get_playlist_videos(PG_DB, self, offset: offset, locale: locale, continuation: continuation)
          videos.each_with_index do |video, index|
            video.to_json(locale, config, Kemal.config, json)
          end
        end
      end
    end
  end

  def to_json(offset, locale, config, kemal_config, json : JSON::Builder? = nil, continuation : String? = nil)
    if json
      to_json(offset, locale, config, kemal_config, json, continuation: continuation)
    else
      JSON.build do |json|
        to_json(offset, locale, config, kemal_config, json, continuation: continuation)
      end
    end
  end

  db_mapping({
    title:            String,
    id:               String,
    author:           String,
    author_thumbnail: String,
    ucid:             String,
    description_html: String,
    video_count:      Int32,
    views:            Int64,
    updated:          Time,
    thumbnail:        String?,
  })

  def privacy
    PlaylistPrivacy::Public
  end
end

enum PlaylistPrivacy
  Public   = 0
  Unlisted = 1
  Private  = 2
end

struct InvidiousPlaylist
  def to_json(offset, locale, config, kemal_config, json : JSON::Builder, continuation : String? = nil)
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
          videos = get_playlist_videos(PG_DB, self, offset: offset, locale: locale, continuation: continuation)
          videos.each_with_index do |video, index|
            video.to_json(locale, config, Kemal.config, json, offset + index)
          end
        end
      end
    end
  end

  def to_json(offset, locale, config, kemal_config, json : JSON::Builder? = nil, continuation : String? = nil)
    if json
      to_json(offset, locale, config, kemal_config, json, continuation: continuation)
    else
      JSON.build do |json|
        to_json(offset, locale, config, kemal_config, json, continuation: continuation)
      end
    end
  end

  property thumbnail_id

  module PlaylistPrivacyConverter
    def self.from_rs(rs)
      return PlaylistPrivacy.parse(String.new(rs.read(Slice(UInt8))))
    end
  end

  db_mapping({
    title:       String,
    id:          String,
    author:      String,
    description: {type: String, default: ""},
    video_count: Int32,
    created:     Time,
    updated:     Time,
    privacy:     {type: PlaylistPrivacy, default: PlaylistPrivacy::Private, converter: PlaylistPrivacyConverter},
    index:       Array(Int64),
  })

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

def create_playlist(db, title, privacy, user)
  plid = "IVPL#{Random::Secure.urlsafe_base64(24)[0, 31]}"

  playlist = InvidiousPlaylist.new(
    title: title.byte_slice(0, 150),
    id: plid,
    author: user.email,
    description: "", # Max 5000 characters
    video_count: 0,
    created: Time.utc,
    updated: Time.utc,
    privacy: privacy,
    index: [] of Int64,
  )

  playlist_array = playlist.to_a
  args = arg_array(playlist_array)

  db.exec("INSERT INTO playlists VALUES (#{args})", args: playlist_array)

  return playlist
end

def extract_playlist(plid, nodeset, index)
  videos = [] of PlaylistVideo

  nodeset.each_with_index do |video, offset|
    anchor = video.xpath_node(%q(.//td[@class="pl-video-title"]))
    if !anchor
      next
    end

    title = anchor.xpath_node(%q(.//a)).not_nil!.content.strip(" \n")
    id = anchor.xpath_node(%q(.//a)).not_nil!["href"].lchop("/watch?v=")[0, 11]

    anchor = anchor.xpath_node(%q(.//div[@class="pl-video-owner"]/a))
    if anchor
      author = anchor.content
      ucid = anchor["href"].split("/")[2]
    else
      author = ""
      ucid = ""
    end

    anchor = video.xpath_node(%q(.//td[@class="pl-video-time"]/div/div[1]))
    if anchor && !anchor.content.empty?
      length_seconds = decode_length_seconds(anchor.content)
      live_now = false
    else
      length_seconds = 0
      live_now = true
    end

    videos << PlaylistVideo.new(
      title: title,
      id: id,
      author: author,
      ucid: ucid,
      length_seconds: length_seconds,
      published: Time.utc,
      plid: plid,
      index: (index + offset).to_i64,
      live_now: live_now
    )
  end

  return videos
end

def produce_playlist_url(id, index)
  if id.starts_with? "UC"
    id = "UU" + id.lchop("UC")
  end
  plid = "VL" + id

  data = {"1:varint" => index.to_i64}
    .try { |i| Protodec::Any.cast_json(i) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i, padding: false) }

  object = {
    "80226972:embedded" => {
      "2:string" => plid,
      "3:base64" => {
        "15:string" => "PT:#{data}",
      },
    },
  }

  continuation = object.try { |i| Protodec::Any.cast_json(object) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return "/browse_ajax?continuation=#{continuation}&gl=US&hl=en"
end

def get_playlist(db, plid, locale, refresh = true, force_refresh = false)
  if plid.starts_with? "IV"
    if playlist = db.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
      return playlist
    else
      raise "Playlist does not exist."
    end
  else
    return fetch_playlist(plid, locale)
  end
end

def fetch_playlist(plid, locale)
  if plid.starts_with? "UC"
    plid = "UU#{plid.lchop("UC")}"
  end

  response = YT_POOL.client &.get("/playlist?list=#{plid}&hl=en&disable_polymer=1")
  if response.status_code != 200
    raise translate(locale, "Not a playlist.")
  end

  body = response.body.gsub(/<button[^>]+><span[^>]+>\s*less\s*<img[^>]+>\n<\/span><\/button>/, "")
  document = XML.parse_html(body)

  title = document.xpath_node(%q(//h1[@class="pl-header-title"]))
  if !title
    raise translate(locale, "Playlist does not exist.")
  end
  title = title.content.strip(" \n")

  description_html = document.xpath_node(%q(//span[@class="pl-header-description-text"]/div/div[1])).try &.to_s ||
                     document.xpath_node(%q(//span[@class="pl-header-description-text"])).try &.to_s || ""

  playlist_thumbnail = document.xpath_node(%q(//div[@class="pl-header-thumb"]/img)).try &.["data-thumb"]? ||
                       document.xpath_node(%q(//div[@class="pl-header-thumb"]/img)).try &.["src"]

  # YouTube allows anonymous playlists, so most of this can be empty or optional
  anchor = document.xpath_node(%q(//ul[@class="pl-header-details"]))
  author = anchor.try &.xpath_node(%q(.//li[1]/a)).try &.content
  author ||= ""
  author_thumbnail = document.xpath_node(%q(//img[@class="channel-header-profile-image"])).try &.["src"]
  author_thumbnail ||= ""
  ucid = anchor.try &.xpath_node(%q(.//li[1]/a)).try &.["href"].split("/")[-1]
  ucid ||= ""

  video_count = anchor.try &.xpath_node(%q(.//li[2])).try &.content.gsub(/\D/, "").to_i?
  video_count ||= 0

  views = anchor.try &.xpath_node(%q(.//li[3])).try &.content.gsub(/\D/, "").to_i64?
  views ||= 0_i64

  updated = anchor.try &.xpath_node(%q(.//li[4])).try &.content.lchop("Last updated on ").lchop("Updated ").try { |date| decode_date(date) }
  updated ||= Time.utc

  playlist = Playlist.new(
    title: title,
    id: plid,
    author: author,
    author_thumbnail: author_thumbnail,
    ucid: ucid,
    description_html: description_html,
    video_count: video_count,
    views: views,
    updated: updated,
    thumbnail: playlist_thumbnail,
  )

  return playlist
end

def get_playlist_videos(db, playlist, offset, locale = nil, continuation = nil)
  if playlist.is_a? InvidiousPlaylist
    if !offset
      index = PG_DB.query_one?("SELECT index FROM playlist_videos WHERE plid = $1 AND id = $2 LIMIT 1", playlist.id, continuation, as: Int64)
      offset = playlist.index.index(index) || 0
    end

    db.query_all("SELECT * FROM playlist_videos WHERE plid = $1 ORDER BY array_position($2, index) LIMIT 100 OFFSET $3", playlist.id, playlist.index, offset, as: PlaylistVideo)
  else
    fetch_playlist_videos(playlist.id, playlist.video_count, offset, locale, continuation)
  end
end

def fetch_playlist_videos(plid, video_count, offset = 0, locale = nil, continuation = nil)
  if continuation
    html = YT_POOL.client &.get("/watch?v=#{continuation}&list=#{plid}&gl=US&hl=en&disable_polymer=1&has_verified=1&bpctr=9999999999")
    html = XML.parse_html(html.body)

    index = html.xpath_node(%q(//span[@id="playlist-current-index"])).try &.content.to_i?.try &.- 1
    offset = index || offset
  end

  if video_count > 100
    url = produce_playlist_url(plid, offset)

    response = YT_POOL.client &.get(url)
    response = JSON.parse(response.body)
    if !response["content_html"]? || response["content_html"].as_s.empty?
      raise translate(locale, "Empty playlist")
    end

    document = XML.parse_html(response["content_html"].as_s)
    nodeset = document.xpath_nodes(%q(.//tr[contains(@class, "pl-video")]))
    videos = extract_playlist(plid, nodeset, offset)
  elsif offset > 100
    return [] of PlaylistVideo
  else # Extract first page of videos
    response = YT_POOL.client &.get("/playlist?list=#{plid}&gl=US&hl=en&disable_polymer=1")
    document = XML.parse_html(response.body)
    nodeset = document.xpath_nodes(%q(.//tr[contains(@class, "pl-video")]))

    videos = extract_playlist(plid, nodeset, 0)
  end

  until videos.empty? || videos[0].index == offset
    videos.shift
  end

  return videos
end

def template_playlist(playlist)
  html = <<-END_HTML
  <h3>
    <a href="/playlist?list=#{playlist["playlistId"]}">
      #{playlist["title"]}
    </a>
  </h3>
  <div class="pure-menu pure-menu-scrollable playlist-restricted">
    <ol class="pure-menu-list">
  END_HTML

  playlist["videos"].as_a.each do |video|
    html += <<-END_HTML
      <li class="pure-menu-item">
        <a href="/watch?v=#{video["videoId"]}&list=#{playlist["playlistId"]}">
          <div class="thumbnail">
              <img class="thumbnail" src="/vi/#{video["videoId"]}/mqdefault.jpg">
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
