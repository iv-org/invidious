class Config
  YAML.mapping({
    video_threads:   Int32,      # Number of threads to use for updating videos in cache (mostly non-functional)
    crawl_threads:   Int32,      # Number of threads to use for finding new videos from YouTube (used to populate "top" page)
    channel_threads: Int32,      # Number of threads to use for crawling videos from channels (for updating subscriptions)
    feed_threads:    Int32,      # Number of threads to use for updating feeds
    db:              NamedTuple( # Database configuration
user: String,
      password: String,
      host: String,
      port: Int32,
      dbname: String,
    ),
    full_refresh:         Bool,                         # Used for crawling channels: threads should check all videos uploaded by a channel
    https_only:           Bool?,                        # Used to tell Invidious it is behind a proxy, so links to resources should be https://
    hmac_key:             String?,                      # HMAC signing key for CSRF tokens and verifying pubsub subscriptions
    domain:               String?,                      # Domain to be used for links to resources on the site where an absolute URL is required
    use_pubsub_feeds:     {type: Bool, default: false}, # Subscribe to channels using PubSubHubbub (requires domain, hmac_key)
    default_home:         {type: String, default: "Top"},
    feed_menu:            {type: Array(String), default: ["Popular", "Top", "Trending", "Subscriptions"]},
    top_enabled:          {type: Bool, default: true},
    captcha_enabled:      {type: Bool, default: true},
    login_enabled:        {type: Bool, default: true},
    registration_enabled: {type: Bool, default: true},
    statistics_enabled:   {type: Bool, default: false},
    admins:               {type: Array(String), default: [] of String},
  })
end

class FilteredCompressHandler < Kemal::Handler
  exclude ["/videoplayback", "/videoplayback/*", "/vi/*", "/api/*", "/ggpht/*"]

  def call(env)
    return call_next env if exclude_match? env

    {% if flag?(:without_zlib) %}
      call_next env
    {% else %}
      request_headers = env.request.headers

      if request_headers.includes_word?("Accept-Encoding", "gzip")
        env.response.headers["Content-Encoding"] = "gzip"
        env.response.output = Gzip::Writer.new(env.response.output, sync_close: true)
      elsif request_headers.includes_word?("Accept-Encoding", "deflate")
        env.response.headers["Content-Encoding"] = "deflate"
        env.response.output = Flate::Writer.new(env.response.output, sync_close: true)
      end

      call_next env
    {% end %}
  end
end

class APIHandler < Kemal::Handler
  only ["/api/v1/*"]

  def call(env)
    return call_next env unless only_match? env

    env.response.headers["Access-Control-Allow-Origin"] = "*"

    call_next env
  end
end

class DenyFrame < Kemal::Handler
  exclude ["/embed/*"]

  def call(env)
    return call_next env if exclude_match? env

    env.response.headers["X-Frame-Options"] = "sameorigin"
    call_next env
  end
end

def rank_videos(db, n)
  top = [] of {Float64, String}

  db.query("SELECT id, wilson_score, published FROM videos WHERE views > 5000 ORDER BY published DESC LIMIT 1000") do |rs|
    rs.each do
      id = rs.read(String)
      wilson_score = rs.read(Float64)
      published = rs.read(Time)

      # Exponential decay, older videos tend to rank lower
      temperature = wilson_score * Math.exp(-0.000005*((Time.now - published).total_minutes))
      top << {temperature, id}
    end
  end

  top.sort!

  # Make hottest come first
  top.reverse!
  top = top.map { |a, b| b }

  return top[0..n - 1]
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

def extract_items(nodeset, ucid = nil, author_name = nil)
  # TODO: Make this a 'common', so it makes more sense to be used here
  items = [] of SearchItem

  nodeset.each do |node|
    anchor = node.xpath_node(%q(.//h3[contains(@class, "yt-lockup-title")]/a))
    if !anchor
      next
    end
    title = anchor.content.strip
    id = anchor["href"]

    if anchor["href"].starts_with? "https://www.googleadservices.com"
      next
    end

    anchor = node.xpath_node(%q(.//div[contains(@class, "yt-lockup-byline")]/a))
    if anchor
      author = anchor.content.strip
      author_id = anchor["href"].split("/")[-1]
    end

    author ||= author_name
    author_id ||= ucid

    author ||= ""
    author_id ||= ""

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

      ucid = node.xpath_node(%q(.//button[contains(@class, "yt-uix-subscription-button")])).try &.["data-channel-external-id"]?
      ucid ||= id.split("/")[-1]

      author_thumbnail = node.xpath_node(%q(.//div/span/img)).try &.["data-thumb"]?
      author_thumbnail ||= node.xpath_node(%q(.//div/span/img)).try &.["src"]
      author_thumbnail ||= ""

      subscriber_count = node.xpath_node(%q(.//span[contains(@class, "yt-subscriber-count")])).try &.["title"].delete(",").to_i?
      subscriber_count ||= 0

      video_count = node.xpath_node(%q(.//ul[@class="yt-lockup-meta-info"]/li)).try &.content.split(" ")[0].delete(",").to_i?
      video_count ||= 0

      items << SearchChannel.new(
        author: author,
        ucid: ucid,
        author_thumbnail: author_thumbnail,
        subscriber_count: subscriber_count,
        video_count: video_count,
        description: description,
        description_html: description_html
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

      if !premium || node.xpath_node(%q(.//span[contains(text(), "Free episode")]))
        paid = false
      else
        paid = true
      end

      items << SearchVideo.new(
        title: title,
        id: id,
        author: author,
        ucid: author_id,
        published: published,
        views: view_count,
        description: description,
        description_html: description_html,
        length_seconds: length_seconds,
        live_now: live_now,
        paid: paid,
        premium: premium
      )
    end
  end

  return items
end

def extract_shelf_items(nodeset, ucid = nil, author_name = nil)
  items = [] of SearchPlaylist

  nodeset.each do |shelf|
    shelf_anchor = shelf.xpath_node(%q(.//h2[contains(@class, "branded-page-module-title")]))

    if !shelf_anchor
      next
    end

    title = shelf_anchor.xpath_node(%q(.//span[contains(@class, "branded-page-module-title-text")]))
    if title
      title = title.content.strip
    end
    title ||= ""

    id = shelf_anchor.xpath_node(%q(.//a)).try &.["href"]
    if !id
      next
    end

    is_playlist = false
    videos = [] of SearchPlaylistVideo

    shelf.xpath_nodes(%q(.//ul[contains(@class, "yt-uix-shelfslider-list")]/li)).each do |child_node|
      type = child_node.xpath_node(%q(./div))
      if !type
        next
      end

      case type["class"]
      when .includes? "yt-lockup-video"
        is_playlist = true

        anchor = child_node.xpath_node(%q(.//h3[contains(@class, "yt-lockup-title")]/a))
        if anchor
          video_title = anchor.content.strip
          video_id = HTTP::Params.parse(URI.parse(anchor["href"]).query.not_nil!)["v"]
        end
        video_title ||= ""
        video_id ||= ""

        anchor = child_node.xpath_node(%q(.//span[@class="video-time"]))
        if anchor
          length_seconds = decode_length_seconds(anchor.content)
        end
        length_seconds ||= 0

        videos << SearchPlaylistVideo.new(
          video_title,
          video_id,
          length_seconds
        )
      when .includes? "yt-lockup-playlist"
        anchor = child_node.xpath_node(%q(.//h3[contains(@class, "yt-lockup-title")]/a))
        if anchor
          playlist_title = anchor.content.strip
          params = HTTP::Params.parse(URI.parse(anchor["href"]).query.not_nil!)
          plid = params["list"]
        end
        playlist_title ||= ""
        plid ||= ""

        items << SearchPlaylist.new(
          playlist_title,
          plid,
          author_name,
          ucid,
          50,
          Array(SearchPlaylistVideo).new
        )
      end
    end

    if is_playlist
      plid = HTTP::Params.parse(URI.parse(id).query.not_nil!)["list"]

      items << SearchPlaylist.new(
        title,
        plid,
        author_name,
        ucid,
        videos.size,
        videos
      )
    end
  end

  return items
end
