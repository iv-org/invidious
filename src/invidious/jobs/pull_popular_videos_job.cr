class Invidious::Jobs::PullPopularVideosJob < Invidious::Jobs::BaseJob
  QUERY = <<-SQL
    SELECT DISTINCT ON (ucid) *
    FROM channel_videos
    WHERE ucid IN (SELECT channel FROM (SELECT UNNEST(subscriptions) AS channel FROM users) AS d
    GROUP BY channel ORDER BY COUNT(channel) DESC LIMIT 40)
    ORDER BY ucid, published DESC
  SQL
  POPULAR_VIDEOS = Atomic.new([] of ChannelVideo)
  private getter db : DB::Database

  def initialize(@db)
  end

  def begin
    loop do
      videos = db.query_all(QUERY, as: ChannelVideo)
        .sort_by(&.published)
        .reverse

      POPULAR_VIDEOS.set(videos)

      sleep 1.minute
      Fiber.yield
    end
  end
end
