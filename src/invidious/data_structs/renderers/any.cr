module YTStructs
  alias Renderers = VideoRenderer | ChannelRenderer | PlaylistRenderer | Category

  # Wrapper object around all renderer types
  struct AnyRenderer
    def initialize(@raw : Renderers)
    end

    # Checks that the underlying value is `VideoRenderer`, and returns its value.
    # Raises otherwise
    def as_video
      @raw.as(VideoRenderer)
    end

    # Checks that the underlying value is `VideoRenderer`, and returns its value.
    # Returns `nil` otherwise
    def as_video?
      as_video if @raw.is_a? VideoRenderer
    end

    # Checks that the underlying value is `ChannelRenderer`, and returns its value.
    # Raises otherwise
    def as_channel
      @raw.as(ChannelRenderer)
    end

    # Checks that the underlying value is `ChannelRenderer`, and returns its value.
    # Raises otherwise
    def as_channel?
      as_channel if @raw.is_a? ChannelRenderer
    end

    # Checks that the underlying value is `PlaylistRenderer`, and returns its value.
    # Raises otherwise
    def as_playlist
      @raw.as(PlaylistRenderer)
    end

    # Checks that the underlying value is `PlaylistRenderer`, and returns its value.
    # Raises otherwise
    def as_playlist?
      as_playlist if @raw.is_a? PlaylistRenderer
    end

    # Checks that the underlying value is `Category`, and returns its value.
    # Raises otherwise
    def as_category
      @raw.as(Category)
    end

    # Checks that the underlying value is `Category`, and returns its value.
    # Raises otherwise
    def as_category?
      as_category if @raw.is_a? Category
    end
  end
end
