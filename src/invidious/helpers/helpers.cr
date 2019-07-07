require "./macros"

struct Nonce
  db_mapping({
    nonce:  String,
    expire: Time,
  })
end

struct SessionId
  db_mapping({
    id:     String,
    email:  String,
    issued: String,
  })
end

struct Annotation
  db_mapping({
    id:          String,
    annotations: String,
  })
end

struct ConfigPreferences
  module StringToArray
    def self.to_yaml(value : Array(String), yaml : YAML::Nodes::Builder)
      yaml.sequence do
        value.each do |element|
          yaml.scalar element
        end
      end
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Array(String)
      begin
        unless node.is_a?(YAML::Nodes::Sequence)
          node.raise "Expected sequence, not #{node.class}"
        end

        result = [] of String
        node.nodes.each do |item|
          unless item.is_a?(YAML::Nodes::Scalar)
            node.raise "Expected scalar, not #{item.class}"
          end

          result << item.value
        end
      rescue ex
        if node.is_a?(YAML::Nodes::Scalar)
          result = [node.value, ""]
        else
          result = ["", ""]
        end
      end

      result
    end
  end

  yaml_mapping({
    annotations:            {type: Bool, default: false},
    annotations_subscribed: {type: Bool, default: false},
    autoplay:               {type: Bool, default: false},
    captions:               {type: Array(String), default: ["", "", ""], converter: StringToArray},
    comments:               {type: Array(String), default: ["youtube", ""], converter: StringToArray},
    continue:               {type: Bool, default: false},
    continue_autoplay:      {type: Bool, default: true},
    dark_mode:              {type: Bool, default: false},
    latest_only:            {type: Bool, default: false},
    listen:                 {type: Bool, default: false},
    local:                  {type: Bool, default: false},
    locale:                 {type: String, default: "en-US"},
    max_results:            {type: Int32, default: 40},
    notifications_only:     {type: Bool, default: false},
    quality:                {type: String, default: "hd720"},
    redirect_feed:          {type: Bool, default: false},
    related_videos:         {type: Bool, default: true},
    sort:                   {type: String, default: "published"},
    speed:                  {type: Float32, default: 1.0_f32},
    thin_mode:              {type: Bool, default: false},
    unseen_only:            {type: Bool, default: false},
    video_loop:             {type: Bool, default: false},
    volume:                 {type: Int32, default: 100},
  })
end

struct Config
  module ConfigPreferencesConverter
    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Preferences
      Preferences.new(*ConfigPreferences.new(ctx, node).to_tuple)
    end

    def self.to_yaml(value : Preferences, yaml : YAML::Nodes::Builder)
      value.to_yaml(yaml)
    end
  end

  def disabled?(option)
    case disabled = CONFIG.disable_proxy
    when Bool
      return disabled
    when Array
      if disabled.includes? option
        return true
      else
        return false
      end
    end
  end

  YAML.mapping({
    channel_threads:          Int32,                                # Number of threads to use for crawling videos from channels (for updating subscriptions)
    feed_threads:             Int32,                                # Number of threads to use for updating feeds
    db:                       DBConfig,                             # Database configuration
    full_refresh:             Bool,                                 # Used for crawling channels: threads should check all videos uploaded by a channel
    https_only:               Bool?,                                # Used to tell Invidious it is behind a proxy, so links to resources should be https://
    hmac_key:                 String?,                              # HMAC signing key for CSRF tokens and verifying pubsub subscriptions
    domain:                   String?,                              # Domain to be used for links to resources on the site where an absolute URL is required
    use_pubsub_feeds:         {type: Bool | Int32, default: false}, # Subscribe to channels using PubSubHubbub (requires domain, hmac_key)
    default_home:             {type: String, default: "Top"},
    feed_menu:                {type: Array(String), default: ["Popular", "Top", "Trending", "Subscriptions"]},
    top_enabled:              {type: Bool, default: true},
    captcha_enabled:          {type: Bool, default: true},
    login_enabled:            {type: Bool, default: true},
    registration_enabled:     {type: Bool, default: true},
    statistics_enabled:       {type: Bool, default: false},
    admins:                   {type: Array(String), default: [] of String},
    external_port:            {type: Int32?, default: nil},
    default_user_preferences: {type: Preferences,
                               default: Preferences.new(*ConfigPreferences.from_yaml("").to_tuple),
                               converter: ConfigPreferencesConverter,
    },
    dmca_content:      {type: Array(String), default: [] of String},   # For compliance with DMCA, disables download widget using list of video IDs
    check_tables:      {type: Bool, default: false},                   # Check table integrity, automatically try to add any missing columns, create tables, etc.
    cache_annotations: {type: Bool, default: false},                   # Cache annotations requested from IA, will not cache empty annotations or annotations that only contain cards
    banner:            {type: String?, default: nil},                  # Optional banner to be displayed along top of page for announcements, etc.
    hsts:              {type: Bool?, default: true},                   # Enables 'Strict-Transport-Security'. Ensure that `domain` and all subdomains are served securely
    disable_proxy:     {type: Bool? | Array(String)?, default: false}, # Disable proxying server-wide: options: 'dash', 'livestreams', 'downloads', 'local'
  })
end

struct DBConfig
  yaml_mapping({
    user:     String,
    password: String,
    host:     String,
    port:     Int32,
    dbname:   String,
  })
end

def rank_videos(db, n)
  top = [] of {Float64, String}

  db.query("SELECT id, wilson_score, published FROM videos WHERE views > 5000 ORDER BY published DESC LIMIT 1000") do |rs|
    rs.each do
      id = rs.read(String)
      wilson_score = rs.read(Float64)
      published = rs.read(Time)

      # Exponential decay, older videos tend to rank lower
      temperature = wilson_score * Math.exp(-0.000005*((Time.utc - published).total_minutes))
      top << {temperature, id}
    end
  end

  top.sort!

  # Make hottest come first
  top.reverse!
  top = top.map { |a, b| b }

  return top[0..n - 1]
end

def login_req(f_req)
  data = {
    # "azt"             => "",
    # "bgHash"          => "",

    # Unfortunately there's not much information available on `bgRequest`; part of Google's BotGuard
    # Generally this is much longer (>1250 characters), similar to Amazon's `metaData1`
    # (see https://github.com/omarroth/audible.cr/blob/master/src/audible/crypto.cr#L43).
    # For now this can be empty.
    "bgRequest"       => %|["identifier","!AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]|,
    "flowName"        => "GlifWebSignIn",
    "flowEntry"       => "ServiceLogin",
    "continue"        => "https://accounts.google.com/ManageAccount",
    "f.req"           => f_req,
    "cookiesDisabled" => "false",
    "deviceinfo"      => %([null,null,null,[],null,"US",null,null,[],"GlifWebSignIn",null,[null,null,[],null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,[],null,null,null,[],[]]]),
    "gmscoreversion"  => "undefined",
    "checkConnection" => "youtube:303:1",
    "checkedDomains"  => "youtube",
    "pstMsg"          => "1",

  }

  return HTTP::Params.encode(data)
end

def html_to_content(description_html : String)
  description = description_html.gsub(/(<br>)|(<br\/>)/, {
    "<br>":  "\n",
    "<br/>": "\n",
  })

  if !description.empty?
    description = XML.parse_html(description).content.strip("\n ")
  end

  return description
end

def extract_videos(nodeset, ucid = nil, author_name = nil)
  videos = extract_items(nodeset, ucid, author_name)
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

    description_html = node.xpath_node(%q(.//div[contains(@class, "yt-lockup-description")])).try &.to_s || ""

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

        video_count = video_count.gsub(/\D/, "").to_i?
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

      playlist_thumbnail = node.xpath_node(%q(.//div/span/img)).try &.["data-thumb"]?
      playlist_thumbnail ||= node.xpath_node(%q(.//div/span/img)).try &.["src"]
      if !playlist_thumbnail || playlist_thumbnail.empty?
        thumbnail_id = videos[0]?.try &.id
      else
        thumbnail_id = playlist_thumbnail.match(/\/vi\/(?<video_id>[a-zA-Z0-9_-]{11})\/\w+\.jpg/).try &.["video_id"]
      end

      items << SearchPlaylist.new(
        title,
        plid,
        author,
        author_id,
        video_count,
        videos,
        thumbnail_id
      )
    when .includes? "yt-lockup-channel"
      author = title.strip

      ucid = node.xpath_node(%q(.//button[contains(@class, "yt-uix-subscription-button")])).try &.["data-channel-external-id"]?
      ucid ||= id.split("/")[-1]

      author_thumbnail = node.xpath_node(%q(.//div/span/img)).try &.["data-thumb"]?
      author_thumbnail ||= node.xpath_node(%q(.//div/span/img)).try &.["src"]
      if author_thumbnail
        author_thumbnail = URI.parse(author_thumbnail)
        author_thumbnail.scheme = "https"
        author_thumbnail = author_thumbnail.to_s
      end

      author_thumbnail ||= ""

      subscriber_count = node.xpath_node(%q(.//span[contains(@class, "yt-subscriber-count")])).try &.["title"].gsub(/\D/, "").to_i?
      subscriber_count ||= 0

      video_count = node.xpath_node(%q(.//ul[@class="yt-lockup-meta-info"]/li)).try &.content.split(" ")[0].gsub(/\D/, "").to_i?
      video_count ||= 0

      items << SearchChannel.new(
        author: author,
        ucid: ucid,
        author_thumbnail: author_thumbnail,
        subscriber_count: subscriber_count,
        video_count: video_count,
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
      published ||= Time.utc

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

      premiere_timestamp = node.xpath_node(%q(.//ul[@class="yt-lockup-meta-info"]/li/span[@class="localized-date"])).try &.["data-timestamp"]?.try &.to_i64
      if premiere_timestamp
        premiere_timestamp = Time.unix(premiere_timestamp)
      end

      items << SearchVideo.new(
        title: title,
        id: id,
        author: author,
        ucid: author_id,
        published: published,
        views: view_count,
        description_html: description_html,
        length_seconds: length_seconds,
        live_now: live_now,
        paid: paid,
        premium: premium,
        premiere_timestamp: premiere_timestamp
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

        playlist_thumbnail = child_node.xpath_node(%q(.//span/img)).try &.["data-thumb"]?
        playlist_thumbnail ||= child_node.xpath_node(%q(.//span/img)).try &.["src"]
        if !playlist_thumbnail || playlist_thumbnail.empty?
          thumbnail_id = videos[0]?.try &.id
        else
          thumbnail_id = playlist_thumbnail.match(/\/vi\/(?<video_id>[a-zA-Z0-9_-]{11})\/\w+\.jpg/).try &.["video_id"]
        end

        video_count_label = child_node.xpath_node(%q(.//span[@class="formatted-video-count-label"]))
        if video_count_label
          video_count = video_count_label.content.gsub(/\D/, "").to_i?
        end
        video_count ||= 50

        items << SearchPlaylist.new(
          playlist_title,
          plid,
          author_name,
          ucid,
          video_count,
          Array(SearchPlaylistVideo).new,
          thumbnail_id
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
        videos,
        videos[0].try &.id
      )
    end
  end

  return items
end

def analyze_table(db, logger, table_name, struct_type = nil)
  # Create table if it doesn't exist
  begin
    db.exec("SELECT * FROM #{table_name} LIMIT 0")
  rescue ex
    logger.puts("CREATE TABLE #{table_name}")

    db.using_connection do |conn|
      conn.as(PG::Connection).exec_all(File.read("config/sql/#{table_name}.sql"))
    end
  end

  if !struct_type
    return
  end

  struct_array = struct_type.to_type_tuple
  column_array = get_column_array(db, table_name)
  column_types = File.read("config/sql/#{table_name}.sql").match(/CREATE TABLE public\.#{table_name}\n\((?<types>[\d\D]*?)\);/)
    .try &.["types"].split(",").map { |line| line.strip }

  if !column_types
    return
  end

  struct_array.each_with_index do |name, i|
    if name != column_array[i]?
      if !column_array[i]?
        new_column = column_types.select { |line| line.starts_with? name }[0]
        logger.puts("ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
        db.exec("ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
        next
      end

      # Column doesn't exist
      if !column_array.includes? name
        new_column = column_types.select { |line| line.starts_with? name }[0]
        db.exec("ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
      end

      # Column exists but in the wrong position, rotate
      if struct_array.includes? column_array[i]
        until name == column_array[i]
          new_column = column_types.select { |line| line.starts_with? column_array[i] }[0]?.try &.gsub("#{column_array[i]}", "#{column_array[i]}_new")

          # There's a column we didn't expect
          if !new_column
            logger.puts("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]}")
            db.exec("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")

            column_array = get_column_array(db, table_name)
            next
          end

          logger.puts("ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
          db.exec("ALTER TABLE #{table_name} ADD COLUMN #{new_column}")

          logger.puts("UPDATE #{table_name} SET #{column_array[i]}_new=#{column_array[i]}")
          db.exec("UPDATE #{table_name} SET #{column_array[i]}_new=#{column_array[i]}")

          logger.puts("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")
          db.exec("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")

          logger.puts("ALTER TABLE #{table_name} RENAME COLUMN #{column_array[i]}_new TO #{column_array[i]}")
          db.exec("ALTER TABLE #{table_name} RENAME COLUMN #{column_array[i]}_new TO #{column_array[i]}")

          column_array = get_column_array(db, table_name)
        end
      else
        logger.puts("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")
        db.exec("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")
      end
    end
  end
end

class PG::ResultSet
  def field(index = @column_index)
    @fields.not_nil![index]
  end
end

def get_column_array(db, table_name)
  column_array = [] of String
  db.query("SELECT * FROM #{table_name} LIMIT 0") do |rs|
    rs.column_count.times do |i|
      column = rs.as(PG::ResultSet).field(i)
      column_array << column.name
    end
  end

  return column_array
end

def cache_annotation(db, id, annotations)
  if !CONFIG.cache_annotations
    return
  end

  body = XML.parse(annotations)
  nodeset = body.xpath_nodes(%q(/document/annotations/annotation))

  if nodeset == 0
    return
  end

  has_legacy_annotations = false
  nodeset.each do |node|
    if !{"branding", "card", "drawer"}.includes? node["type"]?
      has_legacy_annotations = true
      break
    end
  end

  if has_legacy_annotations
    # TODO: Update on conflict?
    db.exec("INSERT INTO annotations VALUES ($1, $2) ON CONFLICT DO NOTHING", id, annotations)
  end
end

def proxy_file(response, env)
  if response.headers.includes_word?("Content-Encoding", "gzip")
    Gzip::Writer.open(env.response) do |deflate|
      response.pipe(deflate)
    end
  elsif response.headers.includes_word?("Content-Encoding", "deflate")
    Flate::Writer.open(env.response) do |deflate|
      response.pipe(deflate)
    end
  else
    response.pipe(env.response)
  end
end

class HTTP::Client::Response
  def pipe(io)
    HTTP.serialize_body(io, headers, @body, @body_io, @version)
  end
end

# Supports serialize_body without first writing headers
module HTTP
  def self.serialize_body(io, headers, body, body_io, version)
    if body
      io << body
    elsif body_io
      content_length = content_length(headers)
      if content_length
        copied = IO.copy(body_io, io)
        if copied != content_length
          raise ArgumentError.new("Content-Length header is #{content_length} but body had #{copied} bytes")
        end
      elsif Client::Response.supports_chunked?(version)
        headers["Transfer-Encoding"] = "chunked"
        serialize_chunked_body(io, body_io)
      else
        io << body
      end
    end
  end
end

def create_notification_stream(env, config, kemal_config, decrypt_function, topics, connection_channel)
  connection = Channel(PQ::Notification).new(8)
  connection_channel.send({true, connection})

  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  since = env.params.query["since"]?.try &.to_i?
  id = 0

  if topics.includes? "debug"
    spawn do
      begin
        loop do
          time_span = [0, 0, 0, 0]
          time_span[rand(4)] = rand(30) + 5
          published = Time.utc - Time::Span.new(time_span[0], time_span[1], time_span[2], time_span[3])
          video_id = TEST_IDS[rand(TEST_IDS.size)]

          video = get_video(video_id, PG_DB)
          video.published = published
          response = JSON.parse(video.to_json(locale, config, kemal_config, decrypt_function))

          if fields_text = env.params.query["fields"]?
            begin
              JSONFilter.filter(response, fields_text)
            rescue ex
              env.response.status_code = 400
              response = {"error" => ex.message}
            end
          end

          env.response.puts "id: #{id}"
          env.response.puts "data: #{response.to_json}"
          env.response.puts
          env.response.flush

          id += 1

          sleep 1.minute
          Fiber.yield
        end
      rescue ex
      end
    end
  end

  spawn do
    begin
      if since
        topics.try &.each do |topic|
          case topic
          when .match(/UC[A-Za-z0-9_-]{22}/)
            PG_DB.query_all("SELECT * FROM channel_videos WHERE ucid = $1 AND published > $2 ORDER BY published DESC LIMIT 15",
              topic, Time.unix(since.not_nil!), as: ChannelVideo).each do |video|
              response = JSON.parse(video.to_json(locale, config, Kemal.config))

              if fields_text = env.params.query["fields"]?
                begin
                  JSONFilter.filter(response, fields_text)
                rescue ex
                  env.response.status_code = 400
                  response = {"error" => ex.message}
                end
              end

              env.response.puts "id: #{id}"
              env.response.puts "data: #{response.to_json}"
              env.response.puts
              env.response.flush

              id += 1
            end
          else
            # TODO
          end
        end
      end
    end
  end

  spawn do
    begin
      loop do
        event = connection.receive

        notification = JSON.parse(event.payload)
        topic = notification["topic"].as_s
        video_id = notification["videoId"].as_s
        published = notification["published"].as_i64

        if !topics.try &.includes? topic
          next
        end

        video = get_video(video_id, PG_DB)
        video.published = Time.unix(published)
        response = JSON.parse(video.to_json(locale, config, Kemal.config, decrypt_function))

        if fields_text = env.params.query["fields"]?
          begin
            JSONFilter.filter(response, fields_text)
          rescue ex
            env.response.status_code = 400
            response = {"error" => ex.message}
          end
        end

        env.response.puts "id: #{id}"
        env.response.puts "data: #{response.to_json}"
        env.response.puts
        env.response.flush

        id += 1
      end
    rescue ex
    ensure
      connection_channel.send({false, connection})
    end
  end

  begin
    # Send heartbeat
    loop do
      env.response.puts ":keepalive #{Time.utc.to_unix}"
      env.response.puts
      env.response.flush
      sleep (20 + rand(11)).seconds
    end
  rescue ex
  ensure
    connection_channel.send({false, connection})
  end
end
