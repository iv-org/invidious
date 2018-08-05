class SearchVideo
  add_mapping({
    title:            String,
    id:               String,
    author:           String,
    ucid:             String,
    published:        Time,
    view_count:       Int64,
    description:      String,
    description_html: String,
    length_seconds:   Int32,
  })
end

def search(query, page = 1, search_params = build_search_params(content_type: "video"))
  client = make_client(YT_URL)
  html = client.get("/results?q=#{URI.escape(query)}&page=#{page}&sp=#{search_params}&disable_polymer=1").body
  if html.empty?
    return [] of SearchVideo
  end

  html = XML.parse_html(html)
  videos = [] of SearchVideo

  html.xpath_nodes(%q(//ol[@class="item-section"]/li)).each do |node|
    anchor = node.xpath_node(%q(.//h3[contains(@class,"yt-lockup-title")]/a))
    if !anchor
      next
    end

    if anchor["href"].starts_with? "https://www.googleadservices.com"
      next
    end

    title = anchor.content.strip
    video_id = anchor["href"].lchop("/watch?v=")

    anchor = node.xpath_node(%q(.//div[contains(@class, "yt-lockup-byline")]/a))
    if !anchor
      next
    end
    author = anchor.content
    author_url = anchor["href"]
    ucid = author_url.split("/")[-1]

    metadata = node.xpath_nodes(%q(.//div[contains(@class,"yt-lockup-meta")]/ul/li))
    if metadata.size == 0
      next
    elsif metadata.size == 1
      view_count = metadata[0].content.split(" ")[0].delete(",").to_i64
      published = Time.now
    else
      # Skip movies
      if metadata[0].content.includes? "·"
        next
      end

      published = decode_date(metadata[0].content)

      view_count = metadata[1].content.split(" ")[0]
      if view_count == "No"
        view_count = 0_i64
      else
        view_count = view_count.delete(",").to_i64
      end
    end

    description_html = node.xpath_node(%q(.//div[contains(@class, "yt-lockup-description")]))
    if !description_html
      description = ""
      description_html = ""
    else
      description_html = description_html.to_s
      description = description_html.gsub("<br>", "\n")
      description = description.gsub("<br/>", "\n")
      description = XML.parse_html(description).content.strip("\n ")
    end

    length_seconds = node.xpath_node(%q(.//span[@class="video-time"]))
    if length_seconds
      length_seconds = decode_length_seconds(length_seconds.content)
    else
      length_seconds = -1
    end

    video = SearchVideo.new(
      title,
      video_id,
      author,
      ucid,
      published,
      view_count,
      description,
      description_html,
      length_seconds,
    )

    videos << video
  end

  return videos
end

def build_search_params(sort_by = "relevance", date : String = "", content_type : String = "", duration : String = "", features : Array(String) = [] of String)
  head = "\x08"
  head += case sort_by
          when "relevance"
            "\x00"
          when "rating"
            "\x01"
          when "upload_date"
            "\x02"
          when "view_count"
            "\x03"
          else
            raise "No sort #{sort_by}"
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
