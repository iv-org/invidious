# API-only mode type definitions
# This file provides dummy type definitions when running in API-only mode

# Dummy DB class for API-only mode
class DummyDB
  def query_all(*args, as : T.class) forall T
    [] of T
  end
  
  def query_one(*args, as : T.class) forall T
    raise "Database not available in API-only mode"
  end
  
  def query_one?(*args, as : T.class) forall T
    nil
  end
  
  def scalar(*args)
    0
  end
  
  def exec(*args)
    nil
  end
end

# VideoNotification struct for API-only mode
struct VideoNotification
  property video_id : String
  property channel_id : String
  property published : Time
  
  def initialize(@video_id = "", @channel_id = "", @published = Time.utc)
  end
  
  def self.from_video(video : ChannelVideo) : VideoNotification
    VideoNotification.new(video.id, video.ucid, video.published)
  end
end

# PQ module with Notification for API-only mode
module PQ
  struct Notification
    property channel : String = ""
    property payload : String = ""
    
    def initialize(@channel = "", @payload = "")
    end
  end
end