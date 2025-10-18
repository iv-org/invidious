require "crypto/bcrypt/password"

# Materialized views may not be defined using bound parameters (`$1` as used elsewhere)
MATERIALIZED_VIEW_SQL = ->(email : String) { "SELECT cv.* FROM channel_videos cv WHERE EXISTS (SELECT subscriptions FROM users u WHERE cv.ucid = ANY (u.subscriptions) AND u.email = E'#{email.gsub({'\'' => "\\'", '\\' => "\\\\"})}') ORDER BY published DESC" }

def create_user(sid, email, password)
  password = Crypto::Bcrypt::Password.create(password, cost: 10)
  token = Base64.urlsafe_encode(Random::Secure.random_bytes(32))

  user = Invidious::User.new({
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

def get_subscription_feed(user, max_results = 40, page = 1)
  limit = max_results.clamp(0, MAX_ITEMS_PER_PAGE)
  offset = (page - 1) * limit

  notifications = Invidious::Database::Users.select_notifications(user)

  if user.preferences.notifications_only && !notifications.empty?
    # Only show notifications
    notifications = Invidious::Database::ChannelVideos.select(notifications)
    videos = [] of ChannelVideo

    notifications.sort_by!(&.published).reverse!

    case user.preferences.sort
    when "alphabetically"
      notifications.sort_by!(&.title)
    when "alphabetically - reverse"
      notifications.sort_by!(&.title).reverse!
    when "channel name"
      notifications.sort_by!(&.author)
    when "channel name - reverse"
      notifications.sort_by!(&.author).reverse!
    else nil # Ignore
    end
  else
    if user.preferences.latest_only
      if user.preferences.unseen_only
        # Show latest video from a channel that a user hasn't watched
        # "unseen_only" isn't really correct here, more accurate would be "unwatched_only"

        # "SELECT cv.* FROM channel_videos cv JOIN users ON cv.ucid = any(users.subscriptions) WHERE users.email = $1 AND published > now() - interval '1 month' ORDER BY published DESC"
        # "SELECT DISTINCT ON (cv.ucid) cv.* FROM channel_videos cv JOIN users ON cv.ucid = any(users.subscriptions) WHERE users.email = ? AND NOT cv.id = any(users.watched) AND published > now() - interval '1 month' ORDER BY ucid, published DESC"
        videos = PG_DB.query_all("SELECT DISTINCT ON (cv.ucid) cv.* " \
                                 "FROM channel_videos cv " \
                                 "JOIN users ON cv.ucid = any(users.subscriptions) " \
                                 "WHERE users.email = $1 AND NOT cv.id = any(users.watched) AND published > now() - interval '1 month' " \
                                 "ORDER BY ucid, published DESC", user.email, as: ChannelVideo)
      else
        # Show latest video from each channel

        videos = PG_DB.query_all("SELECT DISTINCT ON (cv.ucid) cv.* " \
                                 "FROM channel_videos cv " \
                                 "JOIN users ON cv.ucid = any(users.subscriptions) " \
                                 "WHERE users.email = $1 AND published > now() - interval '1 month' " \
                                 "ORDER BY ucid, published DESC", user.email, as: ChannelVideo)
      end

      videos.sort_by!(&.published).reverse!
    else
      if user.preferences.unseen_only
        # Only show unwatched
        videos = PG_DB.query_all("SELECT cv.* " \
                                 "FROM channel_videos cv " \
                                 "JOIN users ON cv.ucid = any(users.subscriptions) " \
                                 "WHERE users.email = $1 AND NOT cv.id = any(users.watched) AND published > now() - interval '1 month' " \
                                 "ORDER BY published DESC LIMIT $2 OFFSET $3", user.email, limit, offset, as: ChannelVideo)
      else
        # Sort subscriptions as normal
        videos = PG_DB.query_all("SELECT cv.* " \
                                 "FROM channel_videos cv " \
                                 "JOIN users ON cv.ucid = any(users.subscriptions) " \
                                 "WHERE users.email = $1 AND published > now() - interval '1 month' " \
                                 "ORDER BY published DESC LIMIT $2 OFFSET $3", user.email, limit, offset, as: ChannelVideo)
      end
    end

    case user.preferences.sort
    when "published - reverse"
      videos.sort_by!(&.published)
    when "alphabetically"
      videos.sort_by!(&.title)
    when "alphabetically - reverse"
      videos.sort_by!(&.title).reverse!
    when "channel name"
      videos.sort_by!(&.author)
    when "channel name - reverse"
      videos.sort_by!(&.author).reverse!
    else nil # Ignore
    end

    notifications = Invidious::Database::Users.select_notifications(user)
    notifications = videos.select { |v| notifications.includes? v.id }
    videos = videos - notifications
  end

  return videos, notifications
end
