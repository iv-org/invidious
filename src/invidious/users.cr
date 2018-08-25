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
    id:            Array(String),
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
  "video_loop"  => false,
  "autoplay"    => false,
  "speed"       => 1.0,
  "quality"     => "hd720",
  "volume"      => 100,
  "comments"    => ["youtube", ""],
  "captions"    => ["", "", ""],
  "dark_mode"   => false,
  "thin_mode "  => false,
  "max_results" => 40,
  "sort"        => "published",
  "latest_only" => false,
  "unseen_only" => false,
}.to_json)

class Preferences
  module StringToArray
    def self.to_json(value : Array(String), json : JSON::Builder)
      return value.to_json
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
    speed:      Float32,
    quality:    String,
    volume:     Int32,
    comments:   {
      type:      Array(String),
      default:   ["youtube", ""],
      converter: StringToArray,
    },
    captions: {
      type:    Array(String),
      default: ["", "", ""],
    },
    redirect_feed: {
      type:    Bool,
      default: false,
    },
    dark_mode: Bool,
    thin_mode: {
      type:    Bool,
      default: false,
    },
    max_results:        Int32,
    sort:               String,
    latest_only:        Bool,
    unseen_only:        Bool,
    notifications_only: {
      type:    Bool,
      default: false,
    },
  })
end

def get_user(sid, client, headers, db, refresh = true)
  if db.query_one?("SELECT EXISTS (SELECT true FROM users WHERE $1 = ANY(id))", sid, as: Bool)
    user = db.query_one("SELECT * FROM users WHERE $1 = ANY(id)", sid, as: User)

    if refresh && Time.now - user.updated > 1.minute
      user = fetch_user(sid, client, headers, db)
      user_array = user.to_a

      user_array[5] = user_array[5].to_json
      args = arg_array(user_array)

      db.exec("INSERT INTO users VALUES (#{args}) \
      ON CONFLICT (email) DO UPDATE SET id = users.id || $1, updated = $2, subscriptions = $4", user_array)
    end
  else
    user = fetch_user(sid, client, headers, db)
    user_array = user.to_a

    user_array[5] = user_array[5].to_json
    args = arg_array(user.to_a)

    db.exec("INSERT INTO users VALUES (#{args}) \
    ON CONFLICT (email) DO UPDATE SET id = users.id || $1, updated = $2, subscriptions = $4", user_array)
  end

  return user
end

def fetch_user(sid, client, headers, db)
  feed = client.get("/subscription_manager?disable_polymer=1", headers)
  feed = XML.parse_html(feed.body)

  channels = [] of String
  feed.xpath_nodes(%q(//ul[@id="guide-channels"]/li/a)).each do |channel|
    if !["Popular on YouTube", "Music", "Sports", "Gaming"].includes? channel["title"]
      channel_id = channel["href"].lstrip("/channel/")

      begin
        channel = get_channel(channel_id, client, db, false, false)
        channels << channel.id
      rescue ex
        next
      end
    end
  end

  email = feed.xpath_node(%q(//a[@class="yt-masthead-picker-header yt-masthead-picker-active-account"]))
  if email
    email = email.content.strip
  else
    email = ""
  end

  token = Base64.urlsafe_encode(Random::Secure.random_bytes(32))

  user = User.new([sid], Time.now, [] of String, channels, email, DEFAULT_USER_PREFERENCES, nil, token, [] of String)
  return user
end

def create_user(sid, email, password)
  password = Crypto::Bcrypt::Password.create(password, cost: 10)
  token = Base64.urlsafe_encode(Random::Secure.random_bytes(32))

  user = User.new([sid], Time.now, [] of String, [] of String, email, DEFAULT_USER_PREFERENCES, password.to_s, token, [] of String)

  return user
end
