require "./macros"

struct Nonce
  include DB::Serializable

  property nonce : String
  property expire : Time
end

struct SessionId
  include DB::Serializable

  property id : String
  property email : String
  property issued : String
end

struct Annotation
  include DB::Serializable

  property id : String
  property annotations : String
end

struct ConfigPreferences
  include YAML::Serializable

  property annotations : Bool = false
  property annotations_subscribed : Bool = false
  property autoplay : Bool = false
  property captions : Array(String) = ["", "", ""]
  property comments : Array(String) = ["youtube", ""]
  property continue : Bool = false
  property continue_autoplay : Bool = true
  property dark_mode : String = ""
  property latest_only : Bool = false
  property listen : Bool = false
  property local : Bool = false
  property locale : String = "en-US"
  property max_results : Int32 = 40
  property notifications_only : Bool = false
  property player_style : String = "invidious"
  property quality : String = "hd720"
  property quality_dash : String = "auto"
  property default_home : String? = "Popular"
  property feed_menu : Array(String) = ["Popular", "Trending", "Subscriptions", "Playlists"]
  property automatic_instance_redirect : Bool = false
  property related_videos : Bool = true
  property sort : String = "published"
  property speed : Float32 = 1.0_f32
  property thin_mode : Bool = false
  property unseen_only : Bool = false
  property video_loop : Bool = false
  property extend_desc : Bool = false
  property volume : Int32 = 100
  property vr_mode : Bool = true
  property show_nick : Bool = true

  def to_tuple
    {% begin %}
      {
        {{*@type.instance_vars.map { |var| "#{var.name}: #{var.name}".id }}}
      }
    {% end %}
  end
end

class Config
  include YAML::Serializable

  property channel_threads : Int32 = 1           # Number of threads to use for crawling videos from channels (for updating subscriptions)
  property feed_threads : Int32 = 1              # Number of threads to use for updating feeds
  property output : String = "STDOUT"            # Log file path or STDOUT
  property log_level : LogLevel = LogLevel::Info # Default log level, valid YAML values are ints and strings, see src/invidious/helpers/logger.cr
  property db : DBConfig? = nil                  # Database configuration with separate parameters (username, hostname, etc)

  @[YAML::Field(converter: Preferences::URIConverter)]
  property database_url : URI = URI.parse("")      # Database configuration using 12-Factor "Database URL" syntax
  property decrypt_polling : Bool = true           # Use polling to keep decryption function up to date
  property full_refresh : Bool = false             # Used for crawling channels: threads should check all videos uploaded by a channel
  property https_only : Bool?                      # Used to tell Invidious it is behind a proxy, so links to resources should be https://
  property hmac_key : String?                      # HMAC signing key for CSRF tokens and verifying pubsub subscriptions
  property domain : String?                        # Domain to be used for links to resources on the site where an absolute URL is required
  property use_pubsub_feeds : Bool | Int32 = false # Subscribe to channels using PubSubHubbub (requires domain, hmac_key)
  property popular_enabled : Bool = true
  property captcha_enabled : Bool = true
  property login_enabled : Bool = true
  property registration_enabled : Bool = true
  property statistics_enabled : Bool = false
  property admins : Array(String) = [] of String
  property external_port : Int32? = nil
  property default_user_preferences : ConfigPreferences = ConfigPreferences.from_yaml("")
  property dmca_content : Array(String) = [] of String    # For compliance with DMCA, disables download widget using list of video IDs
  property check_tables : Bool = false                    # Check table integrity, automatically try to add any missing columns, create tables, etc.
  property cache_annotations : Bool = false               # Cache annotations requested from IA, will not cache empty annotations or annotations that only contain cards
  property banner : String? = nil                         # Optional banner to be displayed along top of page for announcements, etc.
  property hsts : Bool? = true                            # Enables 'Strict-Transport-Security'. Ensure that `domain` and all subdomains are served securely
  property disable_proxy : Bool? | Array(String)? = false # Disable proxying server-wide: options: 'dash', 'livestreams', 'downloads', 'local'

  @[YAML::Field(converter: Preferences::FamilyConverter)]
  property force_resolve : Socket::Family = Socket::Family::UNSPEC # Connect to YouTube over 'ipv6', 'ipv4'. Will sometimes resolve fix issues with rate-limiting (see https://github.com/ytdl-org/youtube-dl/issues/21729)
  property port : Int32 = 3000                                     # Port to listen for connections (overrided by command line argument)
  property host_binding : String = "0.0.0.0"                       # Host to bind (overrided by command line argument)
  property pool_size : Int32 = 100                                 # Pool size for HTTP requests to youtube.com and ytimg.com (each domain has a separate pool of `pool_size`)
  property use_quic : Bool = true                                  # Use quic transport for youtube api

  @[YAML::Field(converter: Preferences::StringToCookies)]
  property cookies : HTTP::Cookies = HTTP::Cookies.new               # Saved cookies in "name1=value1; name2=value2..." format
  property captcha_key : String? = nil                               # Key for Anti-Captcha
  property captcha_api_url : String = "https://api.anti-captcha.com" # API URL for Anti-Captcha

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

  def self.load
    # Load config from file or YAML string env var
    env_config_file = "INVIDIOUS_CONFIG_FILE"
    env_config_yaml = "INVIDIOUS_CONFIG"

    config_file = ENV.has_key?(env_config_file) ? ENV.fetch(env_config_file) : "config/config.yml"
    config_yaml = ENV.has_key?(env_config_yaml) ? ENV.fetch(env_config_yaml) : File.read(config_file)

    config = Config.from_yaml(config_yaml)

    # Update config from env vars (upcased and prefixed with "INVIDIOUS_")
    {% for ivar in Config.instance_vars %}
        {% env_id = "INVIDIOUS_#{ivar.id.upcase}" %}

        if ENV.has_key?({{env_id}})
            # puts %(Config.{{ivar.id}} : Loading from env var {{env_id}})
            env_value = ENV.fetch({{env_id}})
            success = false

            # Use YAML converter if specified
            {% ann = ivar.annotation(::YAML::Field) %}
            {% if ann && ann[:converter] %}
                puts %(Config.{{ivar.id}} : Parsing "#{env_value}" as {{ivar.type}} with {{ann[:converter]}} converter)
                config.{{ivar.id}} = {{ann[:converter]}}.from_yaml(YAML::ParseContext.new, YAML::Nodes.parse(ENV.fetch({{env_id}})).nodes[0])
                puts %(Config.{{ivar.id}} : Set to #{config.{{ivar.id}}})
                success = true

            # Use regular YAML parser otherwise
            {% else %}
                {% ivar_types = ivar.type.union? ? ivar.type.union_types : [ivar.type] %}
                # Sort types to avoid parsing nulls and numbers as strings
                {% ivar_types = ivar_types.sort_by { |ivar_type| ivar_type == Nil ? 0 : ivar_type == Int32 ? 1 : 2 } %}
                {{ivar_types}}.each do |ivar_type|
                    if !success
                        begin
                            # puts %(Config.{{ivar.id}} : Trying to parse "#{env_value}" as #{ivar_type})
                            config.{{ivar.id}} = ivar_type.from_yaml(env_value)
                            puts %(Config.{{ivar.id}} : Set to #{config.{{ivar.id}}} (#{ivar_type}))
                            success = true
                        rescue
                            # nop
                        end
                    end
                end
            {% end %}

            # Exit on fail
            if !success
                puts %(Config.{{ivar.id}} failed to parse #{env_value} as {{ivar.type}})
                exit(1)
            end
        end
    {% end %}

    # Build database_url from db.* if it's not set directly
    if config.database_url.to_s.empty?
      if db = config.db
        config.database_url = URI.new(
          scheme: "postgres",
          user: db.user,
          password: db.password,
          host: db.host,
          port: db.port,
          path: db.dbname,
        )
      else
        puts "Config : Either database_url or db.* is required"
        exit(1)
      end
    end

    return config
  end
end

struct DBConfig
  include YAML::Serializable

  property user : String
  property password : String
  property host : String
  property port : Int32
  property dbname : String
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
  extracted = extract_items(initial_data, author_fallback, author_id_fallback)

  if extracted.is_a?(Category)
    target = extracted.contents
  else
    target = extracted
  end
  return target.select(&.is_a?(SearchVideo)).map(&.as(SearchVideo))
end

def extract_selected_tab(tabs)
  # Extract the selected tab from the array of tabs Youtube returns
  return selected_target = tabs.as_a.select(&.["tabRenderer"]?.try &.["selected"].as_bool)[0]["tabRenderer"]
end

def fetch_continuation_token(items : Array(JSON::Any))
  # Fetches the continuation token from an array of items
  return items.last["continuationItemRenderer"]?
    .try &.["continuationEndpoint"]["continuationCommand"]["token"].as_s
end

def fetch_continuation_token(initial_data : Hash(String, JSON::Any))
  # Fetches the continuation token from initial data
  if initial_data["onResponseReceivedActions"]?
    continuation_items = initial_data["onResponseReceivedActions"][0]["appendContinuationItemsAction"]["continuationItems"]
  else
    tab = extract_selected_tab(initial_data["contents"]["twoColumnBrowseResultsRenderer"]["tabs"])
    continuation_items = tab["content"]["sectionListRenderer"]["contents"][0]["itemSectionRenderer"]["contents"][0]["gridRenderer"]["items"]
  end

  return fetch_continuation_token(continuation_items.as_a)
end

def check_enum(db, enum_name, struct_type = nil)
  return # TODO

  if !db.query_one?("SELECT true FROM pg_type WHERE typname = $1", enum_name, as: Bool)
    LOGGER.info("check_enum: CREATE TYPE #{enum_name}")

    db.using_connection do |conn|
      conn.as(PG::Connection).exec_all(File.read("config/sql/#{enum_name}.sql"))
    end
  end
end

def check_table(db, table_name, struct_type = nil)
  # Create table if it doesn't exist
  begin
    db.exec("SELECT * FROM #{table_name} LIMIT 0")
  rescue ex
    LOGGER.info("check_table: check_table: CREATE TABLE #{table_name}")

    db.using_connection do |conn|
      conn.as(PG::Connection).exec_all(File.read("config/sql/#{table_name}.sql"))
    end
  end

  return if !struct_type

  struct_array = struct_type.type_array
  column_array = get_column_array(db, table_name)
  column_types = File.read("config/sql/#{table_name}.sql").match(/CREATE TABLE public\.#{table_name}\n\((?<types>[\d\D]*?)\);/)
    .try &.["types"].split(",").map { |line| line.strip }.reject &.starts_with?("CONSTRAINT")

  return if !column_types

  struct_array.each_with_index do |name, i|
    if name != column_array[i]?
      if !column_array[i]?
        new_column = column_types.select { |line| line.starts_with? name }[0]
        LOGGER.info("check_table: ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
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
            LOGGER.info("check_table: ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]}")
            db.exec("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")

            column_array = get_column_array(db, table_name)
            next
          end

          LOGGER.info("check_table: ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
          db.exec("ALTER TABLE #{table_name} ADD COLUMN #{new_column}")

          LOGGER.info("check_table: UPDATE #{table_name} SET #{column_array[i]}_new=#{column_array[i]}")
          db.exec("UPDATE #{table_name} SET #{column_array[i]}_new=#{column_array[i]}")

          LOGGER.info("check_table: ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")
          db.exec("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")

          LOGGER.info("check_table: ALTER TABLE #{table_name} RENAME COLUMN #{column_array[i]}_new TO #{column_array[i]}")
          db.exec("ALTER TABLE #{table_name} RENAME COLUMN #{column_array[i]}_new TO #{column_array[i]}")

          column_array = get_column_array(db, table_name)
        end
      else
        LOGGER.info("check_table: ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")
        db.exec("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")
      end
    end
  end

  return if column_array.size <= struct_array.size

  column_array.each do |column|
    if !struct_array.includes? column
      LOGGER.info("check_table: ALTER TABLE #{table_name} DROP COLUMN #{column} CASCADE")
      db.exec("ALTER TABLE #{table_name} DROP COLUMN #{column} CASCADE")
    end
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
  return JSON.parse(body.match(/(window\["ytInitialData"\]|var\s*ytInitialData)\s*=\s*(?<info>{.*?});<\/script>/mx).try &.["info"] || "{}").as_h
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
