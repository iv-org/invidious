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
          when "upload_date"
            "\x02"
          when "view_count"
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
            when "creative_commons"
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
