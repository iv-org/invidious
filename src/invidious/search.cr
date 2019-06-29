struct SearchVideo
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
        xml.element("media:description") { xml.text html_to_content(self.description_html) }
      end

      xml.element("media:community") do
        xml.element("media:statistics", views: self.views)
      end
    end
  end

  def to_xml(host_url, auto_generated, xml : XML::Builder | Nil = nil)
    if xml
      to_xml(host_url, auto_generated, xml)
    else
      XML.build do |json|
        to_xml(host_url, auto_generated, xml)
      end
    end
  end

  def to_json(locale, config, kemal_config, json : JSON::Builder)
    json.object do
      json.field "type", "video"
      json.field "title", self.title
      json.field "videoId", self.id

      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", "/channel/#{self.ucid}"

      json.field "videoThumbnails" do
        generate_thumbnails(json, self.id, config, kemal_config)
      end

      json.field "description", html_to_content(self.description_html)
      json.field "descriptionHtml", self.description_html

      json.field "viewCount", self.views
      json.field "published", self.published.to_unix
      json.field "publishedText", translate(locale, "`x` ago", recode_date(self.published, locale))
      json.field "lengthSeconds", self.length_seconds
      json.field "liveNow", self.live_now
      json.field "paid", self.paid
      json.field "premium", self.premium
    end
  end

  def to_json(locale, config, kemal_config, json : JSON::Builder | Nil = nil)
    if json
      to_json(locale, config, kemal_config, json)
    else
      JSON.build do |json|
        to_json(locale, config, kemal_config, json)
      end
    end
  end

  db_mapping({
    title:              String,
    id:                 String,
    author:             String,
    ucid:               String,
    published:          Time,
    views:              Int64,
    description_html:   String,
    length_seconds:     Int32,
    live_now:           Bool,
    paid:               Bool,
    premium:            Bool,
    premiere_timestamp: Time?,
  })
end

struct SearchPlaylistVideo
  db_mapping({
    title:          String,
    id:             String,
    length_seconds: Int32,
  })
end

struct SearchPlaylist
  def to_json(locale, config, kemal_config, json : JSON::Builder)
    json.object do
      json.field "type", "playlist"
      json.field "title", self.title
      json.field "playlistId", self.id

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
                generate_thumbnails(json, video.id, config, Kemal.config)
              end
            end
          end
        end
      end
    end
  end

  def to_json(locale, config, kemal_config, json : JSON::Builder | Nil = nil)
    if json
      to_json(locale, config, kemal_config, json)
    else
      JSON.build do |json|
        to_json(locale, config, kemal_config, json)
      end
    end
  end

  db_mapping({
    title:        String,
    id:           String,
    author:       String,
    ucid:         String,
    video_count:  Int32,
    videos:       Array(SearchPlaylistVideo),
    thumbnail_id: String?,
  })
end

struct SearchChannel
  def to_json(locale, config, kemal_config, json : JSON::Builder)
    json.object do
      json.field "type", "channel"
      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", "/channel/#{self.ucid}"

      json.field "authorThumbnails" do
        json.array do
          qualities = {32, 48, 76, 100, 176, 512}

          qualities.each do |quality|
            json.object do
              json.field "url", self.author_thumbnail.gsub("=s176-", "=s#{quality}-")
              json.field "width", quality
              json.field "height", quality
            end
          end
        end
      end

      json.field "subCount", self.subscriber_count
      json.field "videoCount", self.video_count
      json.field "description", html_to_content(self.description_html)
      json.field "descriptionHtml", self.description_html
    end
  end

  def to_json(locale, config, kemal_config, json : JSON::Builder | Nil = nil)
    if json
      to_json(locale, config, kemal_config, json)
    else
      JSON.build do |json|
        to_json(locale, config, kemal_config, json)
      end
    end
  end

  db_mapping({
    author:           String,
    ucid:             String,
    author_thumbnail: String,
    subscriber_count: Int32,
    video_count:      Int32,
    description_html: String,
  })
end

alias SearchItem = SearchVideo | SearchChannel | SearchPlaylist

def channel_search(query, page, channel)
  client = make_client(YT_URL)

  response = client.get("/channel/#{channel}?disable_polymer=1&hl=en&gl=US")
  document = XML.parse_html(response.body)
  canonical = document.xpath_node(%q(//link[@rel="canonical"]))

  if !canonical
    response = client.get("/c/#{channel}?disable_polymer=1&hl=en&gl=US")
    document = XML.parse_html(response.body)
    canonical = document.xpath_node(%q(//link[@rel="canonical"]))
  end

  if !canonical
    response = client.get("/user/#{channel}?disable_polymer=1&hl=en&gl=US")
    document = XML.parse_html(response.body)
    canonical = document.xpath_node(%q(//link[@rel="canonical"]))
  end

  if !canonical
    return 0, [] of SearchItem
  end

  ucid = canonical["href"].split("/")[-1]

  url = produce_channel_search_url(ucid, query, page)
  response = client.get(url)
  json = JSON.parse(response.body)

  if json["content_html"]? && !json["content_html"].as_s.empty?
    document = XML.parse_html(json["content_html"].as_s)
    nodeset = document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")]))

    count = nodeset.size
    items = extract_items(nodeset)
  else
    count = 0
    items = [] of SearchItem
  end

  return count, items
end

def search(query, page = 1, search_params = produce_search_params(content_type: "all"), region = nil)
  client = make_client(YT_URL, region)
  if query.empty?
    return {0, [] of SearchItem}
  end

  html = client.get("/results?q=#{URI.escape(query)}&page=#{page}&sp=#{search_params}&hl=en&disable_polymer=1").body
  if html.empty?
    return {0, [] of SearchItem}
  end

  html = XML.parse_html(html)
  nodeset = html.xpath_nodes(%q(//ol[@class="item-section"]/li))
  items = extract_items(nodeset)

  return {nodeset.size, items}
end

def produce_search_params(sort : String = "relevance", date : String = "", content_type : String = "",
                          duration : String = "", features : Array(String) = [] of String)
  head = "\x08"
  head += case sort
          when "relevance"
            "\x00"
          when "rating"
            "\x01"
          when "upload_date", "date"
            "\x02"
          when "view_count", "views"
            "\x03"
          else
            raise "No sort #{sort}"
          end

  body = ""
  body += case date
          when "hour"
            "\x08\x01"
          when "today"
            "\x08\x02"
          when "week"
            "\x08\x03"
          when "month"
            "\x08\x04"
          when "year"
            "\x08\x05"
          else
            ""
          end

  body += case content_type
          when "video"
            "\x10\x01"
          when "channel"
            "\x10\x02"
          when "playlist"
            "\x10\x03"
          when "movie"
            "\x10\x04"
          when "show"
            "\x10\x05"
          when "all"
            ""
          else
            "\x10\x01"
          end

  body += case duration
          when "short"
            "\x18\x01"
          when "long"
            "\x18\x02"
          else
            ""
          end

  features.each do |feature|
    body += case feature
            when "hd"
              "\x20\x01"
            when "subtitles"
              "\x28\x01"
            when "creative_commons", "cc"
              "\x30\x01"
            when "3d"
              "\x38\x01"
            when "live", "livestream"
              "\x40\x01"
            when "purchased"
              "\x48\x01"
            when "4k"
              "\x70\x01"
            when "360"
              "\x78\x01"
            when "location"
              "\xb8\x01\x01"
            when "hdr"
              "\xc8\x01\x01"
            else
              raise "Unknown feature #{feature}"
            end
  end

  if !body.empty?
    token = head + "\x12" + body.size.unsafe_chr + body
  else
    token = head
  end

  token = Base64.urlsafe_encode(token)
  token = URI.escape(token)

  return token
end

def produce_channel_search_url(ucid, query, page)
  page = "#{page}"

  meta = IO::Memory.new
  meta.write(Bytes[0x12, 0x06])
  meta.print("search")

  meta.write(Bytes[0x30, 0x02])
  meta.write(Bytes[0x38, 0x01])
  meta.write(Bytes[0x60, 0x01])
  meta.write(Bytes[0x6a, 0x00])
  meta.write(Bytes[0xb8, 0x01, 0x00])

  meta.write(Bytes[0x7a, page.size])
  meta.print(page)

  meta.rewind
  meta = Base64.urlsafe_encode(meta.to_slice)
  meta = URI.escape(meta)

  continuation = IO::Memory.new
  continuation.write(Bytes[0x12, ucid.size])
  continuation.print(ucid)

  continuation.write(Bytes[0x1a, meta.size])
  continuation.print(meta)

  continuation.write(Bytes[0x5a, query.size])
  continuation.print(query)

  continuation.rewind
  continuation = continuation.gets_to_end

  wrapper = IO::Memory.new
  wrapper.write(Bytes[0xe2, 0xa9, 0x85, 0xb2, 0x02, continuation.size])
  wrapper.print(continuation)
  wrapper.rewind

  wrapper = Base64.urlsafe_encode(wrapper.to_slice)
  wrapper = URI.escape(wrapper)

  url = "/browse_ajax?continuation=#{wrapper}&gl=US&hl=en"

  return url
end
