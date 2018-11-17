class Config
  YAML.mapping({
    crawl_threads:   Int32,
    channel_threads: Int32,
    feed_threads:    Int32,
    video_threads:   Int32,
    db:              NamedTuple(
      user: String,
      password: String,
      host: String,
      port: Int32,
      dbname: String,
    ),
    dl_api_key:   String?,
    https_only:   Bool?,
    hmac_key:     String?,
    full_refresh: Bool,
    geo_bypass:   Bool,
    domain:       String?,
  })
end

def login_req(login_form, f_req)
  data = {
    "pstMsg"          => "1",
    "checkConnection" => "youtube",
    "checkedDomains"  => "youtube",
    "hl"              => "en",
    "deviceinfo"      => %q([null,null,null,[],null,"US",null,null,[],"GlifWebSignIn",null,[null,null,[]]]),
    "f.req"           => f_req,
    "flowName"        => "GlifWebSignIn",
    "flowEntry"       => "ServiceLogin",
  }

  data = login_form.merge(data)

  return HTTP::Params.encode(data)
end

def html_to_content(description_html)
  if !description_html
    description = ""
    description_html = ""
  else
    description_html = description_html.to_s
    description = description_html.gsub("<br>", "\n")
    description = description.gsub("<br/>", "\n")

    if description.empty?
      description = ""
    else
      description = XML.parse_html(description).content.strip("\n ")
    end
  end

  return description_html, description
end

def extract_videos(nodeset, ucid = nil)
  videos = extract_items(nodeset, ucid)
  videos.select! { |item| !item.is_a?(SearchChannel | SearchPlaylist) }
  videos.map { |video| video.as(SearchVideo) }
end

def extract_items(nodeset, ucid = nil)
  # TODO: Make this a 'common', so it makes more sense to be used here
  items = [] of SearchItem

  nodeset.each do |node|
    anchor = node.xpath_node(%q(.//h3[contains(@class,"yt-lockup-title")]/a))
    if !anchor
      next
    end

    if anchor["href"].starts_with? "https://www.googleadservices.com"
      next
    end

    anchor = node.xpath_node(%q(.//div[contains(@class, "yt-lockup-byline")]/a))
    if !anchor
      author = ""
      author_id = ""
    else
      author = anchor.content.strip
      author_id = anchor["href"].split("/")[-1]
    end

    anchor = node.xpath_node(%q(.//h3[contains(@class, "yt-lockup-title")]/a))
    if !anchor
      next
    end
    title = anchor.content.strip
    id = anchor["href"]

    description_html = node.xpath_node(%q(.//div[contains(@class, "yt-lockup-description")]))
    description_html, description = html_to_content(description_html)

    tile = node.xpath_node(%q(.//div[contains(@class, "yt-lockup-tile")]))
    if !tile
      next
    end

    case tile["class"]
    when .includes? "yt-lockup-playlist"
      plid = HTTP::Params.parse(URI.parse(id).query.not_nil!)["list"]

      anchor = node.xpath_node(%q(.//div[contains(@class, "yt-lockup-meta")]/a))

      if !anchor
        anchor = node.xpath_node(%q(.//ul[@class="yt-lockup-meta-info"]/li/a))
      end

      video_count = node.xpath_node(%q(.//span[@class="formatted-video-count-label"]/b))
      if video_count
        video_count = video_count.content

        if video_count == "50+"
          author = "YouTube"
          author_id = "UC-9-kyTW8ZkZNDHQJ6FgpwQ"
          video_count = video_count.rchop("+")
        end

        video_count = video_count.to_i?
      end
      video_count ||= 0

      videos = [] of SearchPlaylistVideo
      node.xpath_nodes(%q(.//*[contains(@class, "yt-lockup-playlist-items")]/li)).each do |video|
        anchor = video.xpath_node(%q(.//a))
        if anchor
          video_title = anchor.content.strip
          id = HTTP::Params.parse(URI.parse(anchor["href"]).query.not_nil!)["v"]
        end
        video_title ||= ""
        id ||= ""

        anchor = video.xpath_node(%q(.//span/span))
        if anchor
          length_seconds = decode_length_seconds(anchor.content)
        end
        length_seconds ||= 0

        videos << SearchPlaylistVideo.new(
          video_title,
          id,
          length_seconds
        )
      end

      items << SearchPlaylist.new(
        title,
        plid,
        author,
        author_id,
        video_count,
        videos
      )
    when .includes? "yt-lockup-channel"
      author = title.strip
      ucid = id.split("/")[-1]

      author_thumbnail = node.xpath_node(%q(.//div/span/img)).try &.["data-thumb"]?
      author_thumbnail ||= node.xpath_node(%q(.//div/span/img)).try &.["src"]
      author_thumbnail ||= ""

      subscriber_count = node.xpath_node(%q(.//span[contains(@class, "yt-subscriber-count")])).try &.["title"].delete(",").to_i?
      subscriber_count ||= 0

      video_count = node.xpath_node(%q(.//ul[@class="yt-lockup-meta-info"]/li)).try &.content.split(" ")[0].delete(",").to_i?
      video_count ||= 0

      items << SearchChannel.new(
        author,
        ucid,
        author_thumbnail,
        subscriber_count,
        video_count,
        description,
        description_html
      )
    else
      id = id.lchop("/watch?v=")

      metadata = node.xpath_nodes(%q(.//div[contains(@class,"yt-lockup-meta")]/ul/li))

      begin
        published = decode_date(metadata[0].content.lchop("Streamed ").lchop("Starts "))
      rescue ex
      end
      begin
        published ||= Time.unix(metadata[0].xpath_node(%q(.//span)).not_nil!["data-timestamp"].to_i64)
      rescue ex
      end
      published ||= Time.now

      begin
        view_count = metadata[0].content.rchop(" watching").delete(",").try &.to_i64?
      rescue ex
      end
      begin
        view_count ||= metadata.try &.[1].content.delete("No views,").try &.to_i64?
      rescue ex
      end
      view_count ||= 0_i64

      length_seconds = node.xpath_node(%q(.//span[@class="video-time"]))
      if length_seconds
        length_seconds = decode_length_seconds(length_seconds.content)
      else
        length_seconds = -1
      end

      live_now = node.xpath_node(%q(.//span[contains(@class, "yt-badge-live")]))
      if live_now
        live_now = true
      else
        live_now = false
      end

      if node.xpath_node(%q(.//span[text()="Premium"]))
        premium = true
      else
        premium = false
      end

      if node.xpath_node(%q(.//span[contains(text(), "Get YouTube Premium")]))
        paid = true
      else
        paid = false
      end

      items << SearchVideo.new(
        title,
        id,
        author,
        author_id,
        published,
        view_count,
        description,
        description_html,
        length_seconds,
        live_now,
        paid,
        premium
      )
    end
  end

  return items
end
