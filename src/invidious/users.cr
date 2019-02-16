require "crypto/bcrypt/password"

class User
  module PreferencesConverter
    def self.from_rs(rs)
      begin
        Preferences.from_json(rs.read(String))
      rescue ex
        DEFAULT_USER_PREFERENCES
      end
    end
  end

  add_mapping({
    updated:       Time,
    notifications: Array(String),
    subscriptions: Array(String),
    email:         String,
    preferences:   {
      type:      Preferences,
      default:   DEFAULT_USER_PREFERENCES,
      converter: PreferencesConverter,
    },
    password: String?,
    token:    String,
    watched:  Array(String),
  })
end

DEFAULT_USER_PREFERENCES = Preferences.from_json({
  "video_loop"         => false,
  "autoplay"           => false,
  "continue"           => false,
  "listen"             => false,
  "speed"              => 1.0,
  "quality"            => "hd720",
  "volume"             => 100,
  "comments"           => ["youtube", ""],
  "captions"           => ["", "", ""],
  "related_videos"     => true,
  "redirect_feed"      => false,
  "locale"             => "en-US",
  "dark_mode"          => false,
  "thin_mode"          => false,
  "max_results"        => 40,
  "sort"               => "published",
  "latest_only"        => false,
  "unseen_only"        => false,
  "notifications_only" => false,
}.to_json)

class Preferences
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
          result << value.read_string
        end
      rescue ex
        result = [value.read_string, ""]
      end

      result
    end
  end

  JSON.mapping({
    video_loop: Bool,
    autoplay:   Bool,
    continue:   {
      type:    Bool,
      default: DEFAULT_USER_PREFERENCES.continue,
    },
    listen: {
      type:    Bool,
      default: DEFAULT_USER_PREFERENCES.listen,
    },
    speed:    Float32,
    quality:  String,
    volume:   Int32,
    comments: {
      type:      Array(String),
      default:   DEFAULT_USER_PREFERENCES.comments,
      converter: StringToArray,
    },
    captions: {
      type:    Array(String),
      default: DEFAULT_USER_PREFERENCES.captions,
    },
    redirect_feed: {
      type:    Bool,
      default: DEFAULT_USER_PREFERENCES.redirect_feed,
    },
    related_videos: {
      type:    Bool,
      default: DEFAULT_USER_PREFERENCES.related_videos,
    },
    dark_mode: Bool,
    thin_mode: {
      type:    Bool,
      default: DEFAULT_USER_PREFERENCES.thin_mode,
    },
    max_results:        Int32,
    sort:               String,
    latest_only:        Bool,
    unseen_only:        Bool,
    notifications_only: {
      type:    Bool,
      default: DEFAULT_USER_PREFERENCES.notifications_only,
    },
    locale: {
      type:    String,
      default: DEFAULT_USER_PREFERENCES.locale,
    },
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
        view_name = "subscriptions_#{sha256(user.email)[0..7]}"
        PG_DB.exec("CREATE MATERIALIZED VIEW #{view_name} AS \
        SELECT * FROM channel_videos WHERE \
        ucid = ANY ((SELECT subscriptions FROM users WHERE email = '#{user.email}')::text[]) \
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
      view_name = "subscriptions_#{sha256(user.email)[0..7]}"
      PG_DB.exec("CREATE MATERIALIZED VIEW #{view_name} AS \
      SELECT * FROM channel_videos WHERE \
      ucid = ANY ((SELECT subscriptions FROM users WHERE email = '#{user.email}')::text[]) \
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

  user = User.new(Time.now, [] of String, channels, email, DEFAULT_USER_PREFERENCES, nil, token, [] of String)
  return user, sid
end

def create_user(sid, email, password)
  password = Crypto::Bcrypt::Password.create(password, cost: 10)
  token = Base64.urlsafe_encode(Random::Secure.random_bytes(32))

  user = User.new(Time.now, [] of String, [] of String, email, DEFAULT_USER_PREFERENCES, password.to_s, token, [] of String)

  return user, sid
end

def create_response(user_id, operation, key, db, expire = 6.hours)
  expire = Time.now + expire
  nonce = Random::Secure.hex(16)
  db.exec("INSERT INTO nonces VALUES ($1, $2) ON CONFLICT DO NOTHING", nonce, expire)

  challenge = "#{expire.to_unix}-#{nonce}-#{user_id}-#{operation}"
  token = OpenSSL::HMAC.digest(:sha256, key, challenge)

  challenge = Base64.urlsafe_encode(challenge)
  token = Base64.urlsafe_encode(token)

  return challenge, token
end

def validate_response(challenge, token, user_id, operation, key, db, locale)
  if !challenge
    raise translate(locale, "Hidden field \"challenge\" is a required field")
  end

  if !token
    raise translate(locale, "Hidden field \"token\" is a required field")
  end

  challenge = Base64.decode_string(challenge)
  if challenge.split("-").size == 4
    expire, nonce, challenge_user_id, challenge_operation = challenge.split("-")

    expire = expire.to_i?
    expire ||= 0
  else
    raise translate(locale, "Invalid challenge")
  end

  challenge = OpenSSL::HMAC.digest(:sha256, HMAC_KEY, challenge)
  challenge = Base64.urlsafe_encode(challenge)

  if db.query_one?("SELECT EXISTS (SELECT true FROM nonces WHERE nonce = $1)", nonce, as: Bool)
    db.exec("DELETE FROM nonces * WHERE nonce = $1", nonce)
  else
    raise translate(locale, "Invalid token")
  end

  if challenge != token
    raise translate(locale, "Invalid token")
  end

  if challenge_operation != operation
    raise translate(locale, "Invalid token")
  end

  if challenge_user_id != user_id
    raise translate(locale, "Invalid user")
  end

  if expire < Time.now.to_unix
    raise translate(locale, "Token is expired, please try again")
  end
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

  challenge, token = create_response(answer, "sign_in", key, db)

  return {image: image, challenge: challenge, token: token}
end
