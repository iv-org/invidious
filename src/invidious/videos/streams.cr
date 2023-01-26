module Invidious::Videos
  # ------------------
  #  Structs & Enums
  # ------------------

  # "AUDIO_QUALITY_"
  enum AudioQuality
    UltraLow
    Low
    Medium
  end

  enum ProjType
    Rectangular
    Equirectangular
    Mesh
  end

  struct ByteRange
    getter start : UInt32
    getter end : UInt32

    def initialize(@start, @end)
    end

    def to_s
      return "#{@start}-#{@end}"
    end
  end

  # ------------------
  #  Traits
  # ------------------

  # Properties common to all streams containing audio
  module AudioProperties
    macro included
      property audio_quality : AudioQuality
      property audio_sample_rate : UInt32
      property audio_channels : UInt8
      property audio_loudness_db : Float64 = 0.0

      private macro init_audio_properties(format)
        @audio_quality = AudioQuality.parse(format["audioQuality"].as_s.lchop("AUDIO_QUALITY_"))
        @audio_sample_rate = format["audioSampleRate"].as_s.to_u32
        @audio_channels = format["audioChannels"].as_i.to_u8
        @audio_loudness_db = format["loudnessDb"]?.try &.as_f || 0.0
      end
    end
  end

  # Properties common to all streams containing video
  module VideoProperties
    macro included
      property video_width : UInt32
      property video_height : UInt32
      property video_fps : UInt16

      private macro init_video_properties(format)
        @video_width = format["width"].as_i.to_u32
        @video_height = format["height"].as_i.to_u32
        @video_fps = format["fps"].as_i.to_u16
      end
    end
  end

  # Properties common to all audio & video streams
  module AVCommonProperties
    macro included
      property bitrate : UInt64
      property bitrate_avg : UInt64?

      # Itag 22 sometimes doesn't have a contentLength ?!
      property content_length : UInt64?

      private macro init_av_common_properties(format)
        @bitrate = format["bitrate"].as_i.to_u64
        @bitrate_avg = format["averageBitrate"]?.try &.as_i.to_u64
        @content_length = format["contentLength"].try &.as_s.to_u64
      end
    end
  end

  # Properties that only applies to mulit-lingual adaptative streams.
  # They apply to audio and text streams (notably text/mp4).
  #
  # Sample JSON for an audio track:
  #   "audioTrack": {
  #     "displayName": "Arabic",
  #     "id": "ar.0",
  #     "audioIsDefault": false
  #   },
  #
  # Sample JSON for a caption track:
  #  "captionTrack": {
  #    "displayName": "English",
  #    "vssId": ".en.eEY6OEpapPo",
  #    "languageCode": "en"
  #  }
  module TrackProperties
    macro included
      property track_id : String?
      property track_name : String = "default"
      property iso_code : String?
      property default : Bool = false

      private macro init_track_properties(format)
        if audio_track = format["audioTrack"]?
          id = audio_track["id"].as_s

          @track_id = id
          @track_name = audio_track["displayName"].as_s

          @iso_code = id.gsub(".0", "")
          @default = audio_track["audioIsDefault"].as_bool
          #
        elsif caption_track = format["captionTrack"]?
          @track_name = caption_track["displayName"].as_s
          @track_id = caption_track["vssId"].as_s
          @iso_code = caption_track["languageCode"].as_s
        end
      end
    end
  end

  # Properties that only apply to adaptative streams of regular videos
  module AdaptativeProperties
    macro included
      property init_range : ByteRange?
      property index_range : ByteRange?

      private macro init_adaptative_properties(format)
        if init_range = format["initRange"]?
          @init_range = ByteRange.new(
            init_range["start"].as_s.to_u32,
            init_range["end"].as_s.to_u32
          )
        end

        if index_range = format["indexRange"]?
          @index_range = ByteRange.new(
            index_range["start"].as_s.to_u32,
            index_range["end"].as_s.to_u32
          )
        end
      end
    end
  end

  # Properties that only apply to adaptative streams from livestrams
  # (either in progress, or recenlty ended)
  module LiveProperties
    macro included
      property target_duration : UInt32?
      property max_dvr_duration : UInt32?

      private macro init_live_properties(format)
        @target_duration = format["targetDurationSec"]?.try(&.as_i.to_u32)
        @max_dvr_duration = format["maxDvrDurationSec"]?.try(&.as_i.to_u32)
      end
    end
  end

  # ------------------
  #  Base class
  # ------------------

  # Base stream class defining all the common properties for all streams
  abstract class Stream
    getter itag : UInt16
    getter label : String
    property url : String

    getter raw_mime_type : String
    getter mime_type : String
    getter codecs : String

    getter last_modified : Time?

    getter projection_type : ProjType

    def initialize(format : JSON::Any, @label)
      @itag = format["itag"].as_i.to_u16
      @url = format["url"].as_s

      @raw_mime_type = format["mimeType"].as_s

      # Extract MIME type and codecs from the raw mimeType string
      @mime_type, raw_codecs = @raw_mime_type.split(';')
      @codecs = raw_codecs.lchop(" codecs=\"").rchop('"')

      # Last modified is not present on livestreams
      if last_modified = format["lastModified"].as_s
        # E.g "1670664306(.)849305"
        # Note: (.) is not present in the input data, it's used here to show
        # the demarcation between seconds and microseconds.
        timestamp = last_modified[0...10]
        microseconds = last_modified[10..]

        @last_modified = Time.utc(
          seconds: timestamp.to_i64,
          nanoseconds: microseconds.to_i * 1000
        )
      end

      @projection_type = ProjType.parse(format["projectionType"].as_s)

      # Initialize extra properties as required
      {% begin %}
        {%
          properties_types = [
            AudioProperties,
            VideoProperties,
            TrackProperties,
            AVCommonProperties,
            AdaptativeProperties,
            LiveProperties,
          ]
        %}

        {% for type in properties_types %}
          # Call the appropriate initialization macro if self
          # inherits from the given type
          {% if @type < type %}
            init_{{type.id.split("::").last.id.underscore}}(format)
          {% end %}
        {% end %}
      {% end %}
    end
  end

  # ------------------
  #  Children classes
  # ------------------

  # An HTTP progressive stream (audio + video)
  class ProgressiveHttpStream < Stream
    include AudioProperties
    include VideoProperties
    include AVCommonProperties
  end

  # Base class for adaptative (DASH) streams
  abstract class AdaptativeStream < Stream
    include AdaptativeProperties
    include LiveProperties
  end

  # An audio-only adaptative (DASH) stream
  class AdaptativeAudioStream < AdaptativeStream
    include AudioProperties
    include AVCommonProperties
  end

  # An audio-only adaptative (DASH) stream with track informations
  class AdaptativeAudioTrackStream < AdaptativeAudioStream
    include TrackProperties
  end

  # A video-only adaptative (DASH) stream
  class AdaptativeVideoStream < AdaptativeStream
    include VideoProperties
    include AVCommonProperties
  end

  # A text-only adaptative (DASH) stream
  class AdaptativeTextStream < AdaptativeStream
    include TrackProperties
  end
end
