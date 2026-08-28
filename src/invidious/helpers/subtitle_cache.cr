module Invidious
  class SubtitleCache
    struct Entry
      getter body : String
      getter content_type : String
      getter created_at : Time
      getter size : Int32

      def initialize(@body : String, @content_type : String, @created_at : Time = Time.utc)
        @size = @body.bytesize
      end

      def expired?(ttl : Time::Span) : Bool
        Time.utc - @created_at > ttl
      end
    end

    DEFAULT_MAX_ENTRIES = 256
    DEFAULT_MAX_BYTES   = 64 * 1024 * 1024 # 64 MiB
    DEFAULT_TTL         = 6.hours          # 21600 seconds
    MAX_ENTRY_BYTES     = 2 * 1024 * 1024  # 2 MiB

    getter max_entries : Int32
    getter max_bytes : Int32
    getter ttl : Time::Span
    getter total_bytes : Int32

    def initialize(@max_entries : Int32 = DEFAULT_MAX_ENTRIES,
                   @max_bytes : Int32 = DEFAULT_MAX_BYTES,
                   @ttl : Time::Span = DEFAULT_TTL)
      @entries = Hash(String, Entry).new
      @total_bytes = 0
      @mutex = Mutex.new
      @in_flight = Hash(String, Array(::Channel(Entry?))).new
    end

    def self.valid_vtt?(body : String) : Bool
      return false if body.empty?
      trimmed = body.lstrip("\uFEFF \t\r\n")
      trimmed.starts_with?("WEBVTT")
    end

    def size : Int32
      @mutex.synchronize { @entries.size }
    end

    def clear : Nil
      @mutex.synchronize do
        @entries.clear
        @total_bytes = 0
      end
    end

    def get(key : String) : Entry?
      @mutex.synchronize do
        get_internal(key)
      end
    end

    private def get_internal(key : String) : Entry?
      if entry = @entries[key]?
        if entry.expired?(@ttl)
          @entries.delete(key)
          @total_bytes -= entry.size
          nil
        else
          # Move to end (most recently used in Crystal Hash)
          @entries.delete(key)
          @entries[key] = entry
          entry
        end
      else
        nil
      end
    end

    def put(key : String, body : String, content_type : String) : Entry?
      return nil unless SubtitleCache.valid_vtt?(body)
      return nil if body.bytesize > MAX_ENTRY_BYTES

      @mutex.synchronize do
        put_internal(key, body, content_type)
      end
    end

    private def put_internal(key : String, body : String, content_type : String) : Entry?
      if old = @entries.delete(key)
        @total_bytes -= old.size
      end

      body_size = body.bytesize

      # Evict LRU entries if capacity exceeded
      while (@entries.size >= @max_entries || @total_bytes + body_size > @max_bytes) && !@entries.empty?
        oldest_key = @entries.first_key
        if removed = @entries.delete(oldest_key)
          @total_bytes -= removed.size
        end
      end

      entry = Entry.new(body, content_type, Time.utc)
      @entries[key] = entry
      @total_bytes += entry.size
      entry
    end

    def get_or_fetch(key : String, &fetch_block : -> Tuple(Int32, String, String)?) : Tuple(Entry?, String)
      wait_ch : ::Channel(Entry?)? = nil

      @mutex.synchronize do
        if entry = get_internal(key)
          return {entry, "hit"}
        end

        if waiting_list = @in_flight[key]?
          ch = ::Channel(Entry?).new(1)
          waiting_list << ch
          wait_ch = ch
        else
          @in_flight[key] = Array(::Channel(Entry?)).new
        end
      end

      if ch = wait_ch
        entry = ch.receive
        if entry
          return {entry, "hit"}
        else
          return {nil, "bypass"}
        end
      end

      # Primary fetcher for this key
      fetch_result = begin
        fetch_block.call
      rescue
        nil
      end

      cached_entry : Entry? = nil
      waiting_channels = Array(::Channel(Entry?)).new

      @mutex.synchronize do
        if fetch_result
          status, content_type, body = fetch_result
          if status == 200 && SubtitleCache.valid_vtt?(body)
            cached_entry = put_internal(key, body, content_type)
          end
        end

        if channels = @in_flight.delete(key)
          waiting_channels = channels
        end
      end

      waiting_channels.each do |w_ch|
        w_ch.send(cached_entry)
      end

      if cached_entry
        {cached_entry, "miss"}
      else
        {nil, "bypass"}
      end
    end
  end
end
