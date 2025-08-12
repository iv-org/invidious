# API-only mode database stubs
# This file provides dummy implementations for database modules when running in API-only mode

module Invidious::Database
  module SessionIDs
    def self.select_email(sid : String) : String?
      nil
    end
    
    def self.select_all(email : String)
      [] of {session: String, issued: Time}
    end
    
    def self.delete(sid : String)
      nil
    end
    
    def self.insert(session : String, email : String)
      nil
    end
  end
  
  module Users
    def self.select!(email : String)
      raise "Database not available in API-only mode"
    end
    
    def self.update_preferences(user)
      nil
    end
    
    def self.mark_watched(user, id)
      nil
    end
    
    def self.mark_unwatched(user, id)
      nil
    end
    
    def self.clear_watch_history(user)
      nil
    end
    
    def self.subscribe_channel(user, ucid)
      nil
    end
    
    def self.unsubscribe_channel(user, ucid)
      nil
    end
    
    def self.update_subscriptions(user)
      nil
    end
    
    def self.update_watch_history(user)
      nil
    end
    
    def self.update_password(user, password : String)
      nil
    end
    
    def self.update(user)
      nil
    end
    
    def self.insert(user)
      nil
    end
    
    def self.delete(user)
      nil
    end
    
    def self.select_notifications(user)
      [] of String
    end
    
    def self.mark_notifications_as_read(user)
      nil
    end
    
    def self.feed_needs_update(user)
      false
    end
    
    def self.update_feed_watched(user)
      nil
    end
  end
  
  module Channels
    def self.select(subscriptions)
      [] of InvidiousChannel
    end
    
    def self.select(id : String)
      nil
    end
    
    def self.insert(channel, update_on_conflict : Bool = false)
      nil
    end
  end
  
  module ChannelVideos
    def self.select_notfications(*args)
      [] of ChannelVideo
    end
    
    def self.select_latest_videos(*args)
      [] of ChannelVideo
    end
    
    def self.insert(*args)
      nil
    end
    
    def self.select(notifications)
      [] of ChannelVideo
    end
  end
  
  module Playlists
    def self.select_all(author : String)
      [] of InvidiousPlaylist
    end
    
    def self.count_owned_by(email : String)
      0
    end
    
    def self.select(id : String)
      nil
    end
    
    def self.update(*args)
      nil
    end
    
    def self.delete(id : String)
      nil
    end
    
    def self.update_video_added(*args)
      nil
    end
    
    def self.update_video_removed(*args)
      nil
    end
    
    def self.select_like_iv(email : String)
      [] of InvidiousPlaylist
    end
    
    def self.insert(playlist)
      nil
    end
    
    def self.update_description(id : String, description : String)
      nil
    end
  end
  
  module PlaylistVideos
    def self.insert(*args)
      nil
    end
    
    def self.delete(*args)
      nil
    end
    
    def self.select_ids(*args, limit : Int32? = nil)
      [] of String
    end
    
    def self.select(*args, limit : Int32? = nil)
      [] of PlaylistVideo
    end
  end
  
  module Annotations
    def self.select(id : String)
      nil
    end
    
    def self.insert(id : String, annotations : String)
      nil
    end
  end
  
  module Videos
    def self.select(id : String)
      nil
    end
    
    def self.insert(*args)
      nil
    end
    
    def self.update(*args)
      nil
    end
    
    def self.delete(id : String)
      nil
    end
  end
  
  module Nonces
    def self.select(nonce : String)
      nil
    end
    
    def self.insert(nonce : String, expire : Time? = nil)
      nil
    end
    
    def self.delete(nonce : String)
      nil
    end
  end
  
  # Migrator stub
  class Migrator
    def initialize(db)
    end
    
    def migrate
      puts "Database migrations are not available in API-only mode"
    end
  end
  
  def self.check_integrity(config)
    # Skip integrity check in API-only mode
  end
end