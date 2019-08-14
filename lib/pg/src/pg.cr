require "db"
require "./pg/*"

module PG
  # Establish a connection to the database
  def self.connect(url)
    DB.open(url)
  end

  # Establish a special listen-only connection to the database.
  #
  # ```
  # PG.connect_listen(ENV["DATABASE_URL"], "foo", "bar") do |notification|
  #   pp notification.channel, notification.payload, notification.pid
  # end
  # ```
  def self.connect_listen(url, *channels : String, &blk : PQ::Notification ->) : ListenConnection
    connect_listen(url, channels, &blk)
  end

  # ditto
  def self.connect_listen(url, channels : Enumerable(String), &blk : PQ::Notification ->) : ListenConnection
    ListenConnection.new(url, channels, &blk)
  end

  class ListenConnection
    @conn : PG::Connection

    def self.new(url, *channels : String, &blk : PQ::Notification ->)
      new(url, channels, &blk)
    end

    def initialize(url, channels : Enumerable(String), &blk : PQ::Notification ->)
      @conn = DB.connect(url).as(PG::Connection)
      @conn.on_notification(&blk)
      @conn.listen(channels)
    end

    # Close the connection.
    def close
      @conn.close
    end
  end
end
