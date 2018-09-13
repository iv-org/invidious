class SearchVideo
  add_mapping({
    title:            String,
    id:               String,
    author:           String,
    ucid:             String,
    published:        Time,
    views:            Int64,
    description:      String,
    description_html: String,
    length_seconds:   Int32,
  })
end

def channel_search(query, page, channel)
  client = make_client(YT_URL)

  response = client.get("/user/#{channel}")
  document = XML.parse_html(response.body)
  canonical = document.xpath_node(%q(//link[@rel="canonical"]))

  if !canonical
    response = client.get("/channel/#{channel}")
    document = XML.parse_html(response.body)
    canonical = document.xpath_node(%q(//link[@rel="canonical"]))
  end

  if !canonical
    return 0, [] of SearchVideo
  end

  ucid = canonical["href"].split("/")[-1]

  url = produce_channel_search_url(ucid, query, page)
  response = client.get(url)
  json = JSON.parse(response.body)

  if json["content_html"]? && !json["content_html"].as_s.empty?
    document = XML.parse_html(json["content_html"].as_s)
    nodeset = document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")]))

    count = nodeset.size
    videos = extract_videos(nodeset)
  else
    count = 0
    videos = [] of SearchVideo
  end

  return count, videos
end

def search(query, page = 1, search_params = build_search_params(content_type: "video"))
  client = make_client(YT_URL)
  if query.empty?
    return {0, [] of SearchVideo}
  end

  html = client.get("/results?q=#{URI.escape(query)}&page=#{page}&sp=#{search_params}&disable_polymer=1").body
  if html.empty?
    return {0, [] of SearchVideo}
  end

  html = XML.parse_html(html)
  nodeset = html.xpath_nodes(%q(//ol[@class="item-section"]/li))
  videos = extract_videos(nodeset)

  return {nodeset.size, videos}
end

def build_search_params(sort : String = "relevance", date : String = "", content_type : String = "",
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
          else
            ""
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
            when "live"
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

  if body.size > 0
    token = head + "\x12" + body.size.to_u8.unsafe_chr + body
  else
    token = head
  end

  token = Base64.urlsafe_encode(token)
  token = URI.escape(token)

  return token
end

def produce_channel_search_url(ucid, query, page)
  page = "#{page}"

  meta = "\x12\x06search0\x02\x38\x01\x60\x01\x6a\x00\x7a"
  meta += page.size.to_u8.unsafe_chr
  meta += page
  meta += "\xb8\x01\x00"

  meta = Base64.urlsafe_encode(meta)
  meta = URI.escape(meta)

  continuation = "\x12"
  continuation += ucid.size.to_u8.unsafe_chr
  continuation += ucid
  continuation += "\x1a"
  continuation += meta.size.to_u8.unsafe_chr
  continuation += meta
  continuation += "\x5a"
  continuation += query.size.to_u8.unsafe_chr
  continuation += query

  continuation = continuation.size.to_u8.unsafe_chr + continuation
  continuation = "\xe2\xa9\x85\xb2\x02" + continuation

  continuation = Base64.urlsafe_encode(continuation)
  continuation = URI.escape(continuation)

  url = "/browse_ajax?continuation=#{continuation}"

  return url
end
