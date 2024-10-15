struct DBConfig
  include YAML::Serializable

  property user : String
  property password : String
  property host : String
  property port : Int32
  property dbname : String
end

struct ConfigPreferences
  include YAML::Serializable

  property annotations : Bool = false
  property annotations_subscribed : Bool = false
  property preload : Bool = true
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
  property watch_history : Bool = true
  property max_results : Int32 = 40
  property notifications_only : Bool = false
  property player_style : String = "invidious"
  property quality : String = "hd720"
  property quality_dash : String = "auto"
  property default_home : String? = "Popular"
  property feed_menu : Array(String) = ["Popular", "Trending", "Subscriptions", "Playlists"]
  property automatic_instance_redirect : Bool = false
  property region : String = "US"
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
  property save_player_pos : Bool = false

  def to_tuple
    {% begin %}
      {
        {{(@type.instance_vars.map { |var| "#{var.name}: #{var.name}".id }).splat}}
      }
    {% end %}
  end
end

class Config
  include YAML::Serializable

  # Number of threads to use for crawling videos from channels (for updating subscriptions)
  property channel_threads : Int32 = 1
  # Time interval between two executions of the job that crawls channel videos (subscriptions update).
  @[YAML::Field(converter: Preferences::TimeSpanConverter)]
  property channel_refresh_interval : Time::Span = 30.minutes
  # Log file path or STDOUT
  property output : String = "STDOUT"
  # Default log level, valid YAML values are ints and strings, see src/invidious/helpers/logger.cr
  property log_level : LogLevel = LogLevel::Info
  # Database configuration with separate parameters (username, hostname, etc)
  property db : DBConfig? = nil

  # Database configuration using 12-Factor "Database URL" syntax
  @[YAML::Field(converter: Preferences::URIConverter)]
  property database_url : URI = URI.parse("")
  # Used for crawling channels: threads should check all videos uploaded by a channel
  property full_refresh : Bool = false

  # Jobs config structure. See jobs.cr and jobs/base_job.cr
  property jobs = Invidious::Jobs::JobsConfig.new

  # Used to tell Invidious it is behind a proxy, so links to resources should be https://
  property https_only : Bool?
  # HMAC signing key for CSRF tokens and verifying pubsub subscriptions
  property hmac_key : String = ""
  # Domain to be used for links to resources on the site where an absolute URL is required
  property domain : String?
  # Subscribe to channels using PubSubHubbub (requires domain, hmac_key)
  property use_pubsub_feeds : Bool | Int32 = false
  property popular_enabled : Bool = true
  property captcha_enabled : Bool = true
  property login_enabled : Bool = true
  property registration_enabled : Bool = true
  property statistics_enabled : Bool = false
  property admins : Array(String) = [] of String
  property external_port : Int32? = nil
  property default_user_preferences : ConfigPreferences = ConfigPreferences.from_yaml("")
  # For compliance with DMCA, disables download widget using list of video IDs
  property dmca_content : Array(String) = [] of String
  # Check table integrity, automatically try to add any missing columns, create tables, etc.
  property check_tables : Bool = false
  # Cache annotations requested from IA, will not cache empty annotations or annotations that only contain cards
  property cache_annotations : Bool = false
  # Optional banner to be displayed along top of page for announcements, etc.
  property banner : String? = nil
  # Enables 'Strict-Transport-Security'. Ensure that `domain` and all subdomains are served securely
  property hsts : Bool? = true
  # Disable proxying server-wide: options: 'dash', 'livestreams', 'downloads', 'local'
  property disable_proxy : Bool? | Array(String)? = false
  # Enable the user notifications for all users
  property enable_user_notifications : Bool = true

  # URL to the modified source code to be easily AGPL compliant
  # Will display in the footer, next to the main source code link
  property modified_source_code_url : String? = nil

  # Connect to YouTube over 'ipv6', 'ipv4'. Will sometimes resolve fix issues with rate-limiting (see https://github.com/ytdl-org/youtube-dl/issues/21729)
  @[YAML::Field(converter: Preferences::FamilyConverter)]
  property force_resolve : Socket::Family = Socket::Family::UNSPEC

  # External signature solver server socket (either a path to a UNIX domain socket or "<IP>:<Port>")
  property signature_server : String? = nil

  # Port to listen for connections (overridden by command line argument)
  property port : Int32 = 3000
  # Host to bind (overridden by command line argument)
  property host_binding : String = "0.0.0.0"
  # Pool size for HTTP requests to youtube.com and ytimg.com (each domain has a separate pool of `pool_size`)
  property pool_size : Int32 = 100

  # Use Innertube's transcripts API instead of timedtext for closed captions
  property use_innertube_for_captions : Bool = false

  # visitor data ID for Google session
  property visitor_data : String? = nil
  # poToken for passing bot attestation
  property po_token : String? = nil

  # Saved cookies in "name1=value1; name2=value2..." format
  @[YAML::Field(converter: Preferences::StringToCookies)]
  property cookies : HTTP::Cookies = HTTP::Cookies.new

  # Playlist length limit
  property playlist_length_limit : Int32 = 500

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
            env_value = ENV.fetch({{env_id}})
            success = false

            # Use YAML converter if specified
            {% ann = ivar.annotation(::YAML::Field) %}
            {% if ann && ann[:converter] %}
                config.{{ivar.id}} = {{ann[:converter]}}.from_yaml(YAML::ParseContext.new, YAML::Nodes.parse(ENV.fetch({{env_id}})).nodes[0])
                success = true

            # Use regular YAML parser otherwise
            {% else %}
                {% ivar_types = ivar.type.union? ? ivar.type.union_types : [ivar.type] %}
                # Sort types to avoid parsing nulls and numbers as strings
                {% ivar_types = ivar_types.sort_by { |ivar_type| ivar_type == Nil ? 0 : ivar_type == Int32 ? 1 : 2 } %}
                {{ivar_types}}.each do |ivar_type|
                    if !success
                        begin
                            config.{{ivar.id}} = ivar_type.from_yaml(env_value)
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

    # HMAC_key is mandatory
    # See: https://github.com/iv-org/invidious/issues/3854
    if config.hmac_key.empty?
      puts "Config: 'hmac_key' is required/can't be empty"
      exit(1)
    elsif config.hmac_key == "CHANGE_ME!!"
      puts "Config: The value of 'hmac_key' needs to be changed!!"
      exit(1)
    end

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
        puts "Config: Either database_url or db.* is required"
        exit(1)
      end
    end

    return config
  end
end
