require "crypto/bcrypt/password"

struct User
  module PreferencesConverter
    def self.from_rs(rs)
      begin
        Preferences.from_json(rs.read(String))
      rescue ex
        Preferences.from_json("{}")
      end
    end
  end

  db_mapping({
    updated:       Time,
    notifications: Array(String),
    subscriptions: Array(String),
    email:         String,
    preferences:   {
      type:      Preferences,
      converter: PreferencesConverter,
    },
    password: String?,
    token:    String,
    watched:  Array(String),
  })
end

struct Preferences
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
          result << HTML.escape(value.read_string)
        end
      rescue ex
        result = [HTML.escape(value.read_string), ""]
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

          result << HTML.escape(item.value)
        end
      rescue ex
        if node.is_a?(YAML::Nodes::Scalar)
          result = [HTML.escape(node.value), ""]
        else
          result = ["", ""]
        end
      end

      result
    end
  end

  module EscapeString
    def self.to_json(value : String, json : JSON::Builder)
      json.string value
    end

    def self.from_json(value : JSON::PullParser) : String
      HTML.escape(value.read_string)
    end

    def self.to_yaml(value : String, yaml : YAML::Nodes::Builder)
      yaml.scalar value
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : String
      HTML.escape(node.value)
    end
  end

  json_mapping({
    annotations:            {type: Bool, default: CONFIG.default_user_preferences.annotations},
    annotations_subscribed: {type: Bool, default: CONFIG.default_user_preferences.annotations_subscribed},
    autoplay:               {type: Bool, default: CONFIG.default_user_preferences.autoplay},
    captions:               {type: Array(String), default: CONFIG.default_user_preferences.captions, converter: StringToArray},
    comments:               {type: Array(String), default: CONFIG.default_user_preferences.comments, converter: StringToArray},
    continue:               {type: Bool, default: CONFIG.default_user_preferences.continue},
    continue_autoplay:      {type: Bool, default: CONFIG.default_user_preferences.continue_autoplay},
    dark_mode:              {type: Bool, default: CONFIG.default_user_preferences.dark_mode},
    latest_only:            {type: Bool, default: CONFIG.default_user_preferences.latest_only},
    listen:                 {type: Bool, default: CONFIG.default_user_preferences.listen},
    local:                  {type: Bool, default: CONFIG.default_user_preferences.local},
    locale:                 {type: String, default: CONFIG.default_user_preferences.locale, converter: EscapeString},
    max_results:            {type: Int32, default: CONFIG.default_user_preferences.max_results},
    notifications_only:     {type: Bool, default: CONFIG.default_user_preferences.notifications_only},
    quality:                {type: String, default: CONFIG.default_user_preferences.quality, converter: EscapeString},
    redirect_feed:          {type: Bool, default: CONFIG.default_user_preferences.redirect_feed},
    related_videos:         {type: Bool, default: CONFIG.default_user_preferences.related_videos},
    sort:                   {type: String, default: CONFIG.default_user_preferences.sort, converter: EscapeString},
    speed:                  {type: Float32, default: CONFIG.default_user_preferences.speed},
    thin_mode:              {type: Bool, default: CONFIG.default_user_preferences.thin_mode},
    unseen_only:            {type: Bool, default: CONFIG.default_user_preferences.unseen_only},
    video_loop:             {type: Bool, default: CONFIG.default_user_preferences.video_loop},
    volume:                 {type: Int32, default: CONFIG.default_user_preferences.volume},
  })
end

def get_user(sid, headers, db, refresh = true)
  if email = db.query_one?("SELECT email FROM session_ids WHERE id = $1", sid, as: String)
    user = db.query_one("SELECT * FROM users WHERE email = $1", email, as: User)

    if refresh && Time.now - user.updated > 1.minute
      user, sid = fetch_user(sid, headers, db)
      user_array = user.to_a

      user_array[4] = user_array[4].to_json
      args = arg_array(user_array)

      db.exec("INSERT INTO users VALUES (#{args}) \
      ON CONFLICT (email) DO UPDATE SET updated = $1, subscriptions = $3", user_array)

      db.exec("INSERT INTO session_ids VALUES ($1,$2,$3) \
      ON CONFLICT (id) DO NOTHING", sid, user.email, Time.now)

      begin
        view_name = "subscriptions_#{sha256(user.email)}"
        db.exec("CREATE MATERIALIZED VIEW #{view_name} AS \
        SELECT * FROM channel_videos WHERE \
        ucid = ANY ((SELECT subscriptions FROM users WHERE email = E'#{user.email.gsub("'", "\\'")}')::text[]) \
        ORDER BY published DESC;")
      rescue ex
      end
    end
  else
    user, sid = fetch_user(sid, headers, db)
    user_array = user.to_a

    user_array[4] = user_array[4].to_json
    args = arg_array(user.to_a)

    db.exec("INSERT INTO users VALUES (#{args}) \
    ON CONFLICT (email) DO UPDATE SET updated = $1, subscriptions = $3", user_array)

    db.exec("INSERT INTO session_ids VALUES ($1,$2,$3) \
    ON CONFLICT (id) DO NOTHING", sid, user.email, Time.now)

    begin
      view_name = "subscriptions_#{sha256(user.email)}"
      db.exec("CREATE MATERIALIZED VIEW #{view_name} AS \
      SELECT * FROM channel_videos WHERE \
      ucid = ANY ((SELECT subscriptions FROM users WHERE email = E'#{user.email.gsub("'", "\\'")}')::text[]) \
      ORDER BY published DESC;")
    rescue ex
    end
  end

  return user, sid
end

def fetch_user(sid, headers, db)
  client = make_client(YT_URL)
  feed = client.get("/subscription_manager?disable_polymer=1", headers)
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

  user = User.new(Time.now, [] of String, channels, email, CONFIG.default_user_preferences, nil, token, [] of String)
  return user, sid
end

def create_user(sid, email, password)
  password = Crypto::Bcrypt::Password.create(password, cost: 10)
  token = Base64.urlsafe_encode(Random::Secure.random_bytes(32))

  user = User.new(Time.now, [] of String, [] of String, email, CONFIG.default_user_preferences, password.to_s, token, [] of String)

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
  <svg viewBox="0 0 100 100" width="200px">
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
  convert = Process.run(%(convert -density 1200 -resize 400x400 -background none svg:- png:-), shell: true,
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
  response = make_client(TEXTCAPTCHA_URL).get("/omarroth@protonmail.com.json").body
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

  client = make_client(YT_URL)
  html = client.get("/subscription_manager?disable_polymer=1", headers)

  cookies = HTTP::Cookies.from_headers(headers)
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

  if match = html.body.match(/'XSRF_TOKEN': "(?<session_token>[A-Za-z0-9\_\-\=]+)"/)
    session_token = match["session_token"]

    headers["content-type"] = "application/x-www-form-urlencoded"

    post_req = {
      "session_token" => session_token,
    }
    post_url = "/subscription_ajax?#{action}=1&c=#{channel_id}"

    client.post(post_url, headers, form: post_req)
  end
end
