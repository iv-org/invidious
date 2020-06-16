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
    def self.to_json(value : Array(String), json : JSON::Builder)
      json.array do
        value.each do |element|
          json.string element
        end
      end
    end

    def self.from_json(value : JSON::PullParser) : Array(String)
      begin
        result = [] of String
        value.read_array do
          result << HTML.escape(value.read_string[0, 100])
        end
      rescue ex
        result = [HTML.escape(value.read_string[0, 100]), ""]
      end

      result
    end

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

          result << HTML.escape(item.value[0, 100])
        end
      rescue ex
        if node.is_a?(YAML::Nodes::Scalar)
          result = [HTML.escape(node.value[0, 100]), ""]
        else
          result = ["", ""]
        end
      end

      result
    end
  end

  module BoolToString
    def self.to_json(value : String, json : JSON::Builder)
      json.string value
    end

    def self.from_json(value : JSON::PullParser) : String
      begin
        result = value.read_string

        if result.empty?
          CONFIG.default_user_preferences.dark_mode
        else
          result
        end
      rescue ex
        if value.read_bool
          "dark"
        else
          "light"
        end
      end
    end

    def self.to_yaml(value : String, yaml : YAML::Nodes::Builder)
      yaml.scalar value
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : String
      unless node.is_a?(YAML::Nodes::Scalar)
        node.raise "Expected scalar, not #{node.class}"
      end

      case node.value
      when "true"
        "dark"
      when "false"
        "light"
      when ""
        CONFIG.default_user_preferences.dark_mode
      else
        node.value
      end
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
    dark_mode:              {type: String, default: "", converter: BoolToString},
    latest_only:            {type: Bool, default: false},
    listen:                 {type: Bool, default: false},
    local:                  {type: Bool, default: false},
    locale:                 {type: String, default: "en-US"},
    max_results:            {type: Int32, default: 40},
    notifications_only:     {type: Bool, default: false},
    player_style:           {type: String, default: "invidious"},
    quality:                {type: String, default: "hd720"},
    default_home:           {type: String, default: "Popular"},
    feed_menu:              {type: Array(String), default: ["Popular", "Trending", "Subscriptions", "Playlists"]},
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
    def self.to_yaml(value : Preferences, yaml : YAML::Nodes::Builder)
      value.to_yaml(yaml)
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Preferences
      Preferences.new(*ConfigPreferences.new(ctx, node).to_tuple)
    end
  end

  module FamilyConverter
    def self.to_yaml(value : Socket::Family, yaml : YAML::Nodes::Builder)
      case value
      when Socket::Family::UNSPEC
        yaml.scalar nil
      when Socket::Family::INET
        yaml.scalar "ipv4"
      when Socket::Family::INET6
        yaml.scalar "ipv6"
      when Socket::Family::UNIX
        raise "Invalid socket family #{value}"
      end
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Socket::Family
      if node.is_a?(YAML::Nodes::Scalar)
        case node.value.downcase
        when "ipv4"
          Socket::Family::INET
        when "ipv6"
          Socket::Family::INET6
        else
          Socket::Family::UNSPEC
        end
      else
        node.raise "Expected scalar, not #{node.class}"
      end
    end
  end

  module StringToCookies
    def self.to_yaml(value : HTTP::Cookies, yaml : YAML::Nodes::Builder)
      (value.map { |c| "#{c.name}=#{c.value}" }).join("; ").to_yaml(yaml)
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : HTTP::Cookies
      unless node.is_a?(YAML::Nodes::Scalar)
        node.raise "Expected scalar, not #{node.class}"
      end

      cookies = HTTP::Cookies.new
      node.value.split(";").each do |cookie|
        next if cookie.strip.empty?
        name, value = cookie.split("=", 2)
        cookies << HTTP::Cookie.new(name.strip, value.strip)
      end

      cookies
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
    else
      return false
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
    dmca_content:      {type: Array(String), default: [] of String},                                        # For compliance with DMCA, disables download widget using list of video IDs
    check_tables:      {type: Bool, default: false},                                                        # Check table integrity, automatically try to add any missing columns, create tables, etc.
    cache_annotations: {type: Bool, default: false},                                                        # Cache annotations requested from IA, will not cache empty annotations or annotations that only contain cards
    banner:            {type: String?, default: nil},                                                       # Optional banner to be displayed along top of page for announcements, etc.
    hsts:              {type: Bool?, default: true},                                                        # Enables 'Strict-Transport-Security'. Ensure that `domain` and all subdomains are served securely
    disable_proxy:     {type: Bool? | Array(String)?, default: false},                                      # Disable proxying server-wide: options: 'dash', 'livestreams', 'downloads', 'local'
    force_resolve:     {type: Socket::Family, default: Socket::Family::UNSPEC, converter: FamilyConverter}, # Connect to YouTube over 'ipv6', 'ipv4'. Will sometimes resolve fix issues with rate-limiting (see https://github.com/ytdl-org/youtube-dl/issues/21729)
    port:              {type: Int32, default: 3000},                                                        # Port to listen for connections (overrided by command line argument)
    host_binding:      {type: String, default: "0.0.0.0"},                                                  # Host to bind (overrided by command line argument)
    pool_size:         {type: Int32, default: 100},                                                         # Pool size for HTTP requests to youtube.com and ytimg.com (each domain has a separate pool of `pool_size`)
    admin_email:       {type: String, default: "omarroth@protonmail.com"},                                  # Email for bug reports
    cookies:           {type: HTTP::Cookies, default: HTTP::Cookies.new, converter: StringToCookies},       # Saved cookies in "name1=value1; name2=value2..." format
    captcha_key:       {type: String?, default: nil},                                                       # Key for Anti-Captcha
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

def login_req(f_req)
  data = {
    # Unfortunately there's not much information available on `bgRequest`; part of Google's BotGuard
    # Generally this is much longer (>1250 characters), see also
    # https://github.com/ytdl-org/youtube-dl/commit/baf67a604d912722b0fe03a40e9dc5349a2208cb .
    # For now this can be empty.
    "bgRequest"       => %|["identifier",""]|,
    "pstMsg"          => "1",
    "checkConnection" => "youtube",
    "checkedDomains"  => "youtube",
    "hl"              => "en",
    "deviceinfo"      => %|[null,null,null,[],null,"US",null,null,[],"GlifWebSignIn",null,[null,null,[]]]|,
    "f.req"           => f_req,
    "flowName"        => "GlifWebSignIn",
    "flowEntry"       => "ServiceLogin",
    # "cookiesDisabled" => "false",
    # "gmscoreversion"  => "undefined",
    # "continue"        => "https://accounts.google.com/ManageAccount",
    # "azt"             => "",
    # "bgHash"          => "",
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

def extract_videos(initial_data : Hash(String, JSON::Any), author_fallback : String? = nil, author_id_fallback : String? = nil)
  extract_items(initial_data, author_fallback, author_id_fallback).select(&.is_a?(SearchVideo)).map(&.as(SearchVideo))
end

def extract_items(initial_data : Hash(String, JSON::Any), author_fallback : String? = nil, author_id_fallback : String? = nil)
  items = [] of SearchItem

  initial_data.try { |t| t["contents"]? || t["response"]? }
    .try { |t| t["twoColumnBrowseResultsRenderer"]?.try &.["tabs"].as_a.select(&.["tabRenderer"]?.try &.["selected"].as_bool)[0]?.try &.["tabRenderer"]["content"] ||
      t["twoColumnSearchResultsRenderer"]?.try &.["primaryContents"] ||
      t["continuationContents"]? }
    .try { |t| t["sectionListRenderer"]? || t["sectionListContinuation"]? }
    .try &.["contents"].as_a
      .each { |c| c.try &.["itemSectionRenderer"]["contents"].as_a
        .try { |t| t[0]?.try &.["shelfRenderer"]?.try &.["content"]["expandedShelfContentsRenderer"]?.try &.["items"].as_a ||
          t[0]?.try &.["gridRenderer"]?.try &.["items"].as_a || t }
        .each { |item|
          if i = item["videoRenderer"]?
            video_id = i["videoId"].as_s
            title = i["title"].try { |t| t["simpleText"]?.try &.as_s || t["runs"]?.try &.as_a.map(&.["text"].as_s).join("") } || ""

            author_info = i["ownerText"]?.try &.["runs"].as_a[0]?
            author = author_info.try &.["text"].as_s || author_fallback || ""
            author_id = author_info.try &.["navigationEndpoint"]?.try &.["browseEndpoint"]["browseId"].as_s || author_id_fallback || ""

            published = i["publishedTimeText"]?.try &.["simpleText"]?.try { |t| decode_date(t.as_s) } || Time.local
            view_count = i["viewCountText"]?.try &.["simpleText"]?.try &.as_s.gsub(/\D+/, "").to_i64? || 0_i64
            description_html = i["descriptionSnippet"]?.try { |t| parse_content(t) } || ""
            length_seconds = i["lengthText"]?.try &.["simpleText"]?.try &.as_s.try { |t| decode_length_seconds(t) } || 0

            live_now = false
            paid = false
            premium = false

            premiere_timestamp = i["upcomingEventData"]?.try &.["startTime"]?.try { |t| Time.unix(t.as_s.to_i64) }

            i["badges"]?.try &.as_a.each do |badge|
              b = badge["metadataBadgeRenderer"]
              case b["label"].as_s
              when "LIVE NOW"
                live_now = true
              when "New", "4K", "CC"
                # TODO
              when "Premium"
                paid = true

                # TODO: Potentially available as i["topStandaloneBadge"]["metadataBadgeRenderer"]
                premium = true
              else nil # Ignore
              end
            end

            items << SearchVideo.new(
              title: title,
              id: video_id,
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
          elsif i = item["channelRenderer"]?
            author = i["title"]["simpleText"]?.try &.as_s || author_fallback || ""
            author_id = i["channelId"]?.try &.as_s || author_id_fallback || ""

            author_thumbnail = i["thumbnail"]["thumbnails"]?.try &.as_a[0]?.try { |u| "https:#{u["url"]}" } || ""
            subscriber_count = i["subscriberCountText"]?.try &.["simpleText"]?.try &.as_s.try { |s| short_text_to_number(s.split(" ")[0]) } || 0

            auto_generated = false
            auto_generated = true if !i["videoCountText"]?
            video_count = i["videoCountText"]?.try &.["runs"].as_a[0]?.try &.["text"].as_s.gsub(/\D/, "").to_i || 0
            description_html = i["descriptionSnippet"]?.try { |t| parse_content(t) } || ""

            items << SearchChannel.new(
              author: author,
              ucid: author_id,
              author_thumbnail: author_thumbnail,
              subscriber_count: subscriber_count,
              video_count: video_count,
              description_html: description_html,
              auto_generated: auto_generated,
            )
          elsif i = item["playlistRenderer"]?
            title = i["title"]["simpleText"]?.try &.as_s || ""
            plid = i["playlistId"]?.try &.as_s || ""

            video_count = i["videoCount"]?.try &.as_s.to_i || 0
            playlist_thumbnail = i["thumbnails"].as_a[0]?.try &.["thumbnails"]?.try &.as_a[0]?.try &.["url"].as_s || ""

            author_info = i["shortBylineText"]?.try &.["runs"].as_a[0]?
            author = author_info.try &.["text"].as_s || author_fallback || ""
            author_id = author_info.try &.["navigationEndpoint"]?.try &.["browseEndpoint"]["browseId"].as_s || author_id_fallback || ""

            videos = i["videos"]?.try &.as_a.map do |v|
              v = v["childVideoRenderer"]
              v_title = v["title"]["simpleText"]?.try &.as_s || ""
              v_id = v["videoId"]?.try &.as_s || ""
              v_length_seconds = v["lengthText"]?.try &.["simpleText"]?.try { |t| decode_length_seconds(t.as_s) } || 0
              SearchPlaylistVideo.new(
                title: v_title,
                id: v_id,
                length_seconds: v_length_seconds
              )
            end || [] of SearchPlaylistVideo

            # TODO: i["publishedTimeText"]?

            items << SearchPlaylist.new(
              title: title,
              id: plid,
              author: author,
              ucid: author_id,
              video_count: video_count,
              videos: videos,
              thumbnail: playlist_thumbnail
            )
          elsif i = item["radioRenderer"]? # Mix
            # TODO
          elsif i = item["showRenderer"]? # Show
            # TODO
          elsif i = item["shelfRenderer"]?
          elsif i = item["horizontalCardListRenderer"]?
          elsif i = item["searchPyvRenderer"]? # Ad
          end
        } }

  items
end

def check_enum(db, logger, enum_name, struct_type = nil)
  return # TODO
  if !db.query_one?("SELECT true FROM pg_type WHERE typname = $1", enum_name, as: Bool)
    logger.puts("CREATE TYPE #{enum_name}")

    db.using_connection do |conn|
      conn.as(PG::Connection).exec_all(File.read("config/sql/#{enum_name}.sql"))
    end
  end
end

def check_table(db, logger, table_name, struct_type = nil)
  # Create table if it doesn't exist
  begin
    db.exec("SELECT * FROM #{table_name} LIMIT 0")
  rescue ex
    logger.puts("CREATE TABLE #{table_name}")

    db.using_connection do |conn|
      conn.as(PG::Connection).exec_all(File.read("config/sql/#{table_name}.sql"))
    end
  end

  return if !struct_type

  struct_array = struct_type.to_type_tuple
  column_array = get_column_array(db, table_name)
  column_types = File.read("config/sql/#{table_name}.sql").match(/CREATE TABLE public\.#{table_name}\n\((?<types>[\d\D]*?)\);/)
    .try &.["types"].split(",").map { |line| line.strip }.reject &.starts_with?("CONSTRAINT")

  return if !column_types

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

  return if column_array.size <= struct_array.size

  column_array.each do |column|
    if !struct_array.includes? column
      logger.puts("ALTER TABLE #{table_name} DROP COLUMN #{column} CASCADE")
      db.exec("ALTER TABLE #{table_name} DROP COLUMN #{column} CASCADE")
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

  return if nodeset == 0

  has_legacy_annotations = false
  nodeset.each do |node|
    if !{"branding", "card", "drawer"}.includes? node["type"]?
      has_legacy_annotations = true
      break
    end
  end

  db.exec("INSERT INTO annotations VALUES ($1, $2) ON CONFLICT DO NOTHING", id, annotations) if has_legacy_annotations
end

def create_notification_stream(env, topics, connection_channel)
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
          published = Time.utc - Time::Span.new(days: time_span[0], hours: time_span[1], minutes: time_span[2], seconds: time_span[3])
          video_id = TEST_IDS[rand(TEST_IDS.size)]

          video = get_video(video_id, PG_DB)
          video.published = published
          response = JSON.parse(video.to_json(locale))

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
              response = JSON.parse(video.to_json(locale))

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
        response = JSON.parse(video.to_json(locale))

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

def extract_initial_data(body) : Hash(String, JSON::Any)
  initial_data = body.match(/window\["ytInitialData"\]\s*=\s*(?<info>.*?);+\n/).try &.["info"] || "{}"
  if initial_data.starts_with?("JSON.parse(\"")
    return JSON.parse(JSON.parse(%({"initial_data":"#{initial_data[12..-3]}"}))["initial_data"].as_s).as_h
  else
    return JSON.parse(initial_data).as_h
  end
end

def proxy_file(response, env)
  if response.headers.includes_word?("Content-Encoding", "gzip")
    Compress::Gzip::Writer.open(env.response) do |deflate|
      IO.copy response.body_io, deflate
    end
  elsif response.headers.includes_word?("Content-Encoding", "deflate")
    Compress::Deflate::Writer.open(env.response) do |deflate|
      IO.copy response.body_io, deflate
    end
  else
    IO.copy response.body_io, env.response
  end
end

# See https://github.com/kemalcr/kemal/pull/576
class HTTP::Server::Response::Output
  def close
    return if closed?

    unless response.wrote_headers?
      response.content_length = @out_count
    end

    ensure_headers_written

    super

    if @chunked
      @io << "0\r\n\r\n"
      @io.flush
    end
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

class HTTP::Client
  property family : Socket::Family = Socket::Family::UNSPEC

  private def socket
    socket = @socket
    return socket if socket

    hostname = @host.starts_with?('[') && @host.ends_with?(']') ? @host[1..-2] : @host
    socket = TCPSocket.new hostname, @port, @dns_timeout, @connect_timeout, @family
    socket.read_timeout = @read_timeout if @read_timeout
    socket.sync = false

    {% if !flag?(:without_openssl) %}
      if tls = @tls
        socket = OpenSSL::SSL::Socket::Client.new(socket, context: tls, sync_close: true, hostname: @host)
      end
    {% end %}

    @socket = socket
  end
end

class TCPSocket
  def initialize(host, port, dns_timeout = nil, connect_timeout = nil, family = Socket::Family::UNSPEC)
    Addrinfo.tcp(host, port, timeout: dns_timeout, family: family) do |addrinfo|
      super(addrinfo.family, addrinfo.type, addrinfo.protocol)
      connect(addrinfo, timeout: connect_timeout) do |error|
        close
        error
      end
    end
  end
end
