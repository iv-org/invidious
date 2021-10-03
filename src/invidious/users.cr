require "crypto/bcrypt/password"

# Materialized views may not be defined using bound parameters (`$1` as used elsewhere)
MATERIALIZED_VIEW_SQL = ->(email : String) { "SELECT cv.* FROM channel_videos cv WHERE EXISTS (SELECT subscriptions FROM users u WHERE cv.ucid = ANY (u.subscriptions) AND u.email = E'#{email.gsub({'\'' => "\\'", '\\' => "\\\\"})}') ORDER BY published DESC" }

struct User
  include DB::Serializable

  property updated : Time
  property notifications : Array(String)
  property subscriptions : Array(String)
  property email : String

  @[DB::Field(converter: User::PreferencesConverter)]
  property preferences : Preferences
  property password : String?
  property token : String
  property watched : Array(String)
  property feed_needs_update : Bool?

  module PreferencesConverter
    def self.from_rs(rs)
      begin
        Preferences.from_json(rs.read(String))
      rescue ex
        Preferences.from_json("{}")
      end
    end
  end
end

struct Preferences
  include JSON::Serializable
  include YAML::Serializable

  property annotations : Bool = CONFIG.default_user_preferences.annotations
  property annotations_subscribed : Bool = CONFIG.default_user_preferences.annotations_subscribed
  property autoplay : Bool = CONFIG.default_user_preferences.autoplay
  property automatic_instance_redirect : Bool = CONFIG.default_user_preferences.automatic_instance_redirect

  @[JSON::Field(converter: Preferences::StringToArray)]
  @[YAML::Field(converter: Preferences::StringToArray)]
  property captions : Array(String) = CONFIG.default_user_preferences.captions

  @[JSON::Field(converter: Preferences::StringToArray)]
  @[YAML::Field(converter: Preferences::StringToArray)]
  property comments : Array(String) = CONFIG.default_user_preferences.comments
  property continue : Bool = CONFIG.default_user_preferences.continue
  property continue_autoplay : Bool = CONFIG.default_user_preferences.continue_autoplay

  @[JSON::Field(converter: Preferences::BoolToString)]
  @[YAML::Field(converter: Preferences::BoolToString)]
  property dark_mode : String = CONFIG.default_user_preferences.dark_mode
  property latest_only : Bool = CONFIG.default_user_preferences.latest_only
  property listen : Bool = CONFIG.default_user_preferences.listen
  property local : Bool = CONFIG.default_user_preferences.local
  property vr_mode : Bool = CONFIG.default_user_preferences.vr_mode
  property show_nick : Bool = CONFIG.default_user_preferences.show_nick

  @[JSON::Field(converter: Preferences::ProcessString)]
  property locale : String = CONFIG.default_user_preferences.locale

  @[JSON::Field(converter: Preferences::ClampInt)]
  property max_results : Int32 = CONFIG.default_user_preferences.max_results
  property notifications_only : Bool = CONFIG.default_user_preferences.notifications_only

  @[JSON::Field(converter: Preferences::ProcessString)]
  property player_style : String = CONFIG.default_user_preferences.player_style

  @[JSON::Field(converter: Preferences::ProcessString)]
  property quality : String = CONFIG.default_user_preferences.quality
  @[JSON::Field(converter: Preferences::ProcessString)]
  property quality_dash : String = CONFIG.default_user_preferences.quality_dash
  property default_home : String? = CONFIG.default_user_preferences.default_home
  property feed_menu : Array(String) = CONFIG.default_user_preferences.feed_menu
  property related_videos : Bool = CONFIG.default_user_preferences.related_videos

  @[JSON::Field(converter: Preferences::ProcessString)]
  property sort : String = CONFIG.default_user_preferences.sort
  property speed : Float32 = CONFIG.default_user_preferences.speed
  property thin_mode : Bool = CONFIG.default_user_preferences.thin_mode
  property unseen_only : Bool = CONFIG.default_user_preferences.unseen_only
  property video_loop : Bool = CONFIG.default_user_preferences.video_loop
  property extend_desc : Bool = CONFIG.default_user_preferences.extend_desc
  property volume : Int32 = CONFIG.default_user_preferences.volume

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

  module ClampInt
    def self.to_json(value : Int32, json : JSON::Builder)
      json.number value
    end

    def self.from_json(value : JSON::PullParser) : Int32
      value.read_int.clamp(0, MAX_ITEMS_PER_PAGE).to_i32
    end

    def self.to_yaml(value : Int32, yaml : YAML::Nodes::Builder)
      yaml.scalar value
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Int32
      node.value.clamp(0, MAX_ITEMS_PER_PAGE)
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

  module URIConverter
    def self.to_yaml(value : URI, yaml : YAML::Nodes::Builder)
      yaml.scalar value.normalize!
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : URI
      if node.is_a?(YAML::Nodes::Scalar)
        URI.parse node.value
      else
        node.raise "Expected scalar, not #{node.class}"
      end
    end
  end

  module ProcessString
    def self.to_json(value : String, json : JSON::Builder)
      json.string value
    end

    def self.from_json(value : JSON::PullParser) : String
      HTML.escape(value.read_string[0, 100])
    end

    def self.to_yaml(value : String, yaml : YAML::Nodes::Builder)
      yaml.scalar value
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : String
      HTML.escape(node.value[0, 100])
    end
  end

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
end

def get_user(sid, headers, db, refresh = true)
  if email = db.query_one?("SELECT email FROM session_ids WHERE id = $1", sid, as: String)
    user = db.query_one("SELECT * FROM users WHERE email = $1", email, as: User)

    if refresh && Time.utc - user.updated > 1.minute
      user, sid = fetch_user(sid, headers, db)
      user_array = user.to_a
      user_array[4] = user_array[4].to_json # User preferences
      args = arg_array(user_array)

      db.exec("INSERT INTO users VALUES (#{args}) \
      ON CONFLICT (email) DO UPDATE SET updated = $1, subscriptions = $3", args: user_array)

      db.exec("INSERT INTO session_ids VALUES ($1,$2,$3) \
      ON CONFLICT (id) DO NOTHING", sid, user.email, Time.utc)

      begin
        view_name = "subscriptions_#{sha256(user.email)}"
        db.exec("CREATE MATERIALIZED VIEW #{view_name} AS #{MATERIALIZED_VIEW_SQL.call(user.email)}")
      rescue ex
      end
    end
  else
    user, sid = fetch_user(sid, headers, db)
    user_array = user.to_a
    user_array[4] = user_array[4].to_json # User preferences
    args = arg_array(user.to_a)

    db.exec("INSERT INTO users VALUES (#{args}) \
    ON CONFLICT (email) DO UPDATE SET updated = $1, subscriptions = $3", args: user_array)

    db.exec("INSERT INTO session_ids VALUES ($1,$2,$3) \
    ON CONFLICT (id) DO NOTHING", sid, user.email, Time.utc)

    begin
      view_name = "subscriptions_#{sha256(user.email)}"
      db.exec("CREATE MATERIALIZED VIEW #{view_name} AS #{MATERIALIZED_VIEW_SQL.call(user.email)}")
    rescue ex
    end
  end

  return user, sid
end

def fetch_user(sid, headers, db)
  feed = YT_POOL.client &.get("/subscription_manager?disable_polymer=1", headers)
  feed = XML.parse_html(feed.body)

  channels = [] of String
  channels = feed.xpath_nodes(%q(//ul[@id="guide-channels"]/li/a)).compact_map do |channel|
    if {"Popular on YouTube", "Music", "Sports", "Gaming"}.includes? channel["title"]
      nil
    else
      channel["href"].lstrip("/channel/")
    end
  end

  channels = get_batch_channels(channels, db, false, false)

  email = feed.xpath_node(%q(//a[@class="yt-masthead-picker-header yt-masthead-picker-active-account"]))
  if email
    email = email.content.strip
  else
    email = ""
  end

  token = Base64.urlsafe_encode(Random::Secure.random_bytes(32))

  user = User.new({
    updated:           Time.utc,
    notifications:     [] of String,
    subscriptions:     channels,
    email:             email,
    preferences:       Preferences.new(CONFIG.default_user_preferences.to_tuple),
    password:          nil,
    token:             token,
    watched:           [] of String,
    feed_needs_update: true,
  })
  return user, sid
end

def create_user(sid, email, password)
  password = Crypto::Bcrypt::Password.create(password, cost: 10)
  token = Base64.urlsafe_encode(Random::Secure.random_bytes(32))

  user = User.new({
    updated:           Time.utc,
    notifications:     [] of String,
    subscriptions:     [] of String,
    email:             email,
    preferences:       Preferences.new(CONFIG.default_user_preferences.to_tuple),
    password:          password.to_s,
    token:             token,
    watched:           [] of String,
    feed_needs_update: true,
  })

  return user, sid
end

def generate_captcha(key, db)
  second = Random::Secure.rand(12)
  second_angle = second * 30
  second = second * 5

  minute = Random::Secure.rand(12)
  minute_angle = minute * 30
  minute = minute * 5

  hour = Random::Secure.rand(12)
  hour_angle = hour * 30 + minute_angle.to_f / 12
  if hour == 0
    hour = 12
  end

  clock_svg = <<-END_SVG
  <svg viewBox="0 0 100 100" width="200px" height="200px">
  <circle cx="50" cy="50" r="45" fill="#eee" stroke="black" stroke-width="2"></circle>

  <text x="69"     y="20.091" text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 1</text>
  <text x="82.909" y="34"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 2</text>
  <text x="88"     y="53"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 3</text>
  <text x="82.909" y="72"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 4</text>
  <text x="69"     y="85.909" text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 5</text>
  <text x="50"     y="91"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 6</text>
  <text x="31"     y="85.909" text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 7</text>
  <text x="17.091" y="72"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 8</text>
  <text x="12"     y="53"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 9</text>
  <text x="17.091" y="34"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px">10</text>
  <text x="31"     y="20.091" text-anchor="middle" fill="black" font-family="Arial" font-size="10px">11</text>
  <text x="50"     y="15"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px">12</text>

  <circle cx="50" cy="50" r="3" fill="black"></circle>
  <line id="second" transform="rotate(#{second_angle}, 50, 50)" x1="50" y1="50" x2="50" y2="12" fill="black" stroke="black" stroke-width="1"></line>
  <line id="minute" transform="rotate(#{minute_angle}, 50, 50)" x1="50" y1="50" x2="50" y2="16" fill="black" stroke="black" stroke-width="2"></line>
  <line id="hour"   transform="rotate(#{hour_angle}, 50, 50)" x1="50" y1="50" x2="50" y2="24" fill="black" stroke="black" stroke-width="2"></line>
  </svg>
  END_SVG

  image = ""
  convert = Process.run(%(rsvg-convert -w 400 -h 400 -b none -f png), shell: true,
    input: IO::Memory.new(clock_svg), output: Process::Redirect::Pipe) do |proc|
    image = proc.output.gets_to_end
    image = Base64.strict_encode(image)
    image = "data:image/png;base64,#{image}"
  end

  answer = "#{hour}:#{minute.to_s.rjust(2, '0')}:#{second.to_s.rjust(2, '0')}"
  answer = OpenSSL::HMAC.hexdigest(:sha256, key, answer)

  return {
    question: image,
    tokens:   {generate_response(answer, {":login"}, key, db, use_nonce: true)},
  }
end

def generate_text_captcha(key, db)
  response = make_client(TEXTCAPTCHA_URL, &.get("/github.com/iv.org/invidious.json").body)
  response = JSON.parse(response)

  tokens = response["a"].as_a.map do |answer|
    generate_response(answer.as_s, {":login"}, key, db, use_nonce: true)
  end

  return {
    question: response["q"].as_s,
    tokens:   tokens,
  }
end

def subscribe_ajax(channel_id, action, env_headers)
  headers = HTTP::Headers.new
  headers["Cookie"] = env_headers["Cookie"]

  html = YT_POOL.client &.get("/subscription_manager?disable_polymer=1", headers)

  cookies = HTTP::Cookies.from_client_headers(headers)
  html.cookies.each do |cookie|
    if {"VISITOR_INFO1_LIVE", "YSC", "SIDCC"}.includes? cookie.name
      if cookies[cookie.name]?
        cookies[cookie.name] = cookie
      else
        cookies << cookie
      end
    end
  end
  headers = cookies.add_request_headers(headers)

  if match = html.body.match(/'XSRF_TOKEN': "(?<session_token>[^"]+)"/)
    session_token = match["session_token"]

    headers["content-type"] = "application/x-www-form-urlencoded"

    post_req = {
      session_token: session_token,
    }
    post_url = "/subscription_ajax?#{action}=1&c=#{channel_id}"

    YT_POOL.client &.post(post_url, headers, form: post_req)
  end
end

def get_subscription_feed(db, user, max_results = 40, page = 1)
  limit = max_results.clamp(0, MAX_ITEMS_PER_PAGE)
  offset = (page - 1) * limit

  notifications = db.query_one("SELECT notifications FROM users WHERE email = $1", user.email,
    as: Array(String))
  view_name = "subscriptions_#{sha256(user.email)}"

  if user.preferences.notifications_only && !notifications.empty?
    # Only show notifications

    args = arg_array(notifications)

    notifications = db.query_all("SELECT * FROM channel_videos WHERE id IN (#{args}) ORDER BY published DESC", args: notifications, as: ChannelVideo)
    videos = [] of ChannelVideo

    notifications.sort_by! { |video| video.published }.reverse!

    case user.preferences.sort
    when "alphabetically"
      notifications.sort_by! { |video| video.title }
    when "alphabetically - reverse"
      notifications.sort_by! { |video| video.title }.reverse!
    when "channel name"
      notifications.sort_by! { |video| video.author }
    when "channel name - reverse"
      notifications.sort_by! { |video| video.author }.reverse!
    else nil # Ignore
    end
  else
    if user.preferences.latest_only
      if user.preferences.unseen_only
        # Show latest video from a channel that a user hasn't watched
        # "unseen_only" isn't really correct here, more accurate would be "unwatched_only"

        if user.watched.empty?
          values = "'{}'"
        else
          values = "VALUES #{user.watched.map { |id| %(('#{id}')) }.join(",")}"
        end
        videos = PG_DB.query_all("SELECT DISTINCT ON (ucid) * FROM #{view_name} WHERE NOT id = ANY (#{values}) ORDER BY ucid, published DESC", as: ChannelVideo)
      else
        # Show latest video from each channel

        videos = PG_DB.query_all("SELECT DISTINCT ON (ucid) * FROM #{view_name} ORDER BY ucid, published DESC", as: ChannelVideo)
      end

      videos.sort_by! { |video| video.published }.reverse!
    else
      if user.preferences.unseen_only
        # Only show unwatched

        if user.watched.empty?
          values = "'{}'"
        else
          values = "VALUES #{user.watched.map { |id| %(('#{id}')) }.join(",")}"
        end
        videos = PG_DB.query_all("SELECT * FROM #{view_name} WHERE NOT id = ANY (#{values}) ORDER BY published DESC LIMIT $1 OFFSET $2", limit, offset, as: ChannelVideo)
      else
        # Sort subscriptions as normal

        videos = PG_DB.query_all("SELECT * FROM #{view_name} ORDER BY published DESC LIMIT $1 OFFSET $2", limit, offset, as: ChannelVideo)
      end
    end

    case user.preferences.sort
    when "published - reverse"
      videos.sort_by! { |video| video.published }
    when "alphabetically"
      videos.sort_by! { |video| video.title }
    when "alphabetically - reverse"
      videos.sort_by! { |video| video.title }.reverse!
    when "channel name"
      videos.sort_by! { |video| video.author }
    when "channel name - reverse"
      videos.sort_by! { |video| video.author }.reverse!
    else nil # Ignore
    end

    notifications = PG_DB.query_one("SELECT notifications FROM users WHERE email = $1", user.email, as: Array(String))

    notifications = videos.select { |v| notifications.includes? v.id }
    videos = videos - notifications
  end

  return videos, notifications
end
