struct VideoNotification
  getter video_id : String
  getter channel_id : String
  getter published : Time

  def_hash @channel_id, @video_id

  def ==(other)
    video_id == other.video_id
  end

  def self.from_video(video : ChannelVideo) : self
    VideoNotification.new(video.id, video.ucid, video.published)
  end

  def initialize(@video_id, @channel_id, @published)
  end

  def clone : VideoNotification
    VideoNotification.new(video_id.clone, channel_id.clone, published.clone)
  end
end

class Invidious::Jobs::NotificationJob < Invidious::Jobs::BaseJob
  private getter notification_channel : ::Channel(VideoNotification)
  private getter connection_channel : ::Channel({Bool, ::Channel(PQ::Notification)})
  private getter pg_url : URI

  def initialize(@notification_channel, @connection_channel, @pg_url)
  end

  def begin
    connections = [] of ::Channel(PQ::Notification)

    PG.connect_listen(pg_url, "notifications") { |event| connections.each(&.send(event)) }

    # hash of channels to their videos (id+published) that need notifying
    to_notify = Hash(String, Set(VideoNotification)).new(
      ->(hash : Hash(String, Set(VideoNotification)), key : String) {
        hash[key] = Set(VideoNotification).new
      }
    )
    notify_mutex = Mutex.new()

    # fiber to locally cache all incoming notifications (from pubsub webhooks and refresh channels job)
    spawn do
      begin
        loop do
          notification = notification_channel.receive
          notify_mutex.synchronize do
            to_notify[notification.channel_id] << notification
          end
        end
      end
    end
    # fiber to regularly persist all cached notifications
    spawn do
      loop do
        begin
          LOGGER.debug("NotificationJob: waking up")
          cloned = {} of String => Set(VideoNotification)
          notify_mutex.synchronize do
            cloned = to_notify.clone
            to_notify.clear
          end

          cloned.each do |channel_id, notifications|
            if notifications.empty?
              next
            end

            LOGGER.info("NotificationJob: updating channel #{channel_id} with #{notifications.size} notifications")
            if CONFIG.enable_user_notifications
              video_ids = notifications.map { |n| n.video_id }
              Invidious::Database::Users.add_multiple_notifications(channel_id, video_ids)
              PG_DB.using_connection do |conn|
                notifications.each do |n|
                  # Deliver notifications to `/api/v1/auth/notifications`
                  payload = {
                    "topic"     => n.channel_id,
                    "videoId"   => n.video_id,
                    "published" => n.published.to_unix,
                  }.to_json
                  conn.exec("NOTIFY notifications, E'#{payload}'")
                end
              end
            else
              Invidious::Database::Users.feed_needs_update(channel_id)
            end
          end

          LOGGER.trace("NotificationJob: Done, sleeping")
        rescue ex
          LOGGER.error("NotificationJob: #{ex.message}")
        end
        sleep 1.minute
        Fiber.yield
      end
    end

    loop do
      action, connection = connection_channel.receive

      case action
      when true
        connections << connection
      when false
        connections.delete(connection)
      end
    end
  end
end
