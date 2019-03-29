struct SearchVideo
  add_mapping({
    title:              String,
    id:                 String,
    author:             String,
    ucid:               String,
    published:          Time,
    views:              Int64,
    description:        String,
    description_html:   String,
    length_seconds:     Int32,
    live_now:           Bool,
    paid:               Bool,
    premium:            Bool,
    premiere_timestamp: Time?,
  })
end

struct SearchPlaylistVideo
  add_mapping({
    title:          String,
    id:             String,
    length_seconds: Int32,
  })
end

struct SearchPlaylist
  add_mapping({
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
  add_mapping({
    author:           String,
    ucid:             String,
    author_thumbnail: String,
    subscriber_count: Int32,
    video_count:      Int32,
    description:      String,
    description_html: String,
  })
end

alias SearchItem = SearchVideo | SearchChannel | SearchPlaylist

def channel_search(query, page, channel)
  client = make_client(YT_URL)

  response = client.get("/user/#{channel}?disable_polymer=1&hl=en&gl=US")
  document = XML.parse_html(response.body)
  canonical = document.xpath_node(%q(//link[@rel="canonical"]))

  if !canonical
    response = client.get("/channel/#{channel}?disable_polymer=1&hl=en&gl=US")
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

def search(query, page = 1, search_params = produce_search_params(content_type: "all"), proxies = nil, region = nil)
  client = make_client(YT_URL, proxies, region)
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
