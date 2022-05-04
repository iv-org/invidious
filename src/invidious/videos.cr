CAPTION_LANGUAGES = {
  "",
  "English",
  "English (auto-generated)",
  "English (United Kingdom)",
  "English (United States)",
  "Afrikaans",
  "Albanian",
  "Amharic",
  "Arabic",
  "Armenian",
  "Azerbaijani",
  "Bangla",
  "Basque",
  "Belarusian",
  "Bosnian",
  "Bulgarian",
  "Burmese",
  "Cantonese (Hong Kong)",
  "Catalan",
  "Cebuano",
  "Chinese",
  "Chinese (China)",
  "Chinese (Hong Kong)",
  "Chinese (Simplified)",
  "Chinese (Taiwan)",
  "Chinese (Traditional)",
  "Corsican",
  "Croatian",
  "Czech",
  "Danish",
  "Dutch",
  "Dutch (auto-generated)",
  "Esperanto",
  "Estonian",
  "Filipino",
  "Finnish",
  "French",
  "French (auto-generated)",
  "Galician",
  "Georgian",
  "German",
  "German (auto-generated)",
  "Greek",
  "Gujarati",
  "Haitian Creole",
  "Hausa",
  "Hawaiian",
  "Hebrew",
  "Hindi",
  "Hmong",
  "Hungarian",
  "Icelandic",
  "Igbo",
  "Indonesian",
  "Indonesian (auto-generated)",
  "Interlingue",
  "Irish",
  "Italian",
  "Italian (auto-generated)",
  "Japanese",
  "Japanese (auto-generated)",
  "Javanese",
  "Kannada",
  "Kazakh",
  "Khmer",
  "Korean",
  "Korean (auto-generated)",
  "Kurdish",
  "Kyrgyz",
  "Lao",
  "Latin",
  "Latvian",
  "Lithuanian",
  "Luxembourgish",
  "Macedonian",
  "Malagasy",
  "Malay",
  "Malayalam",
  "Maltese",
  "Maori",
  "Marathi",
  "Mongolian",
  "Nepali",
  "Norwegian Bokmål",
  "Nyanja",
  "Pashto",
  "Persian",
  "Polish",
  "Portuguese",
  "Portuguese (auto-generated)",
  "Portuguese (Brazil)",
  "Punjabi",
  "Romanian",
  "Russian",
  "Russian (auto-generated)",
  "Samoan",
  "Scottish Gaelic",
  "Serbian",
  "Shona",
  "Sindhi",
  "Sinhala",
  "Slovak",
  "Slovenian",
  "Somali",
  "Southern Sotho",
  "Spanish",
  "Spanish (auto-generated)",
  "Spanish (Latin America)",
  "Spanish (Mexico)",
  "Spanish (Spain)",
  "Sundanese",
  "Swahili",
  "Swedish",
  "Tajik",
  "Tamil",
  "Telugu",
  "Thai",
  "Turkish",
  "Turkish (auto-generated)",
  "Ukrainian",
  "Urdu",
  "Uzbek",
  "Vietnamese",
  "Vietnamese (auto-generated)",
  "Welsh",
  "Western Frisian",
  "Xhosa",
  "Yiddish",
  "Yoruba",
  "Zulu",
}

REGIONS = {"AD", "AE", "AF", "AG", "AI", "AL", "AM", "AO", "AQ", "AR", "AS", "AT", "AU", "AW", "AX", "AZ", "BA", "BB", "BD", "BE", "BF", "BG", "BH", "BI", "BJ", "BL", "BM", "BN", "BO", "BQ", "BR", "BS", "BT", "BV", "BW", "BY", "BZ", "CA", "CC", "CD", "CF", "CG", "CH", "CI", "CK", "CL", "CM", "CN", "CO", "CR", "CU", "CV", "CW", "CX", "CY", "CZ", "DE", "DJ", "DK", "DM", "DO", "DZ", "EC", "EE", "EG", "EH", "ER", "ES", "ET", "FI", "FJ", "FK", "FM", "FO", "FR", "GA", "GB", "GD", "GE", "GF", "GG", "GH", "GI", "GL", "GM", "GN", "GP", "GQ", "GR", "GS", "GT", "GU", "GW", "GY", "HK", "HM", "HN", "HR", "HT", "HU", "ID", "IE", "IL", "IM", "IN", "IO", "IQ", "IR", "IS", "IT", "JE", "JM", "JO", "JP", "KE", "KG", "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ", "LA", "LB", "LC", "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY", "MA", "MC", "MD", "ME", "MF", "MG", "MH", "MK", "ML", "MM", "MN", "MO", "MP", "MQ", "MR", "MS", "MT", "MU", "MV", "MW", "MX", "MY", "MZ", "NA", "NC", "NE", "NF", "NG", "NI", "NL", "NO", "NP", "NR", "NU", "NZ", "OM", "PA", "PE", "PF", "PG", "PH", "PK", "PL", "PM", "PN", "PR", "PS", "PT", "PW", "PY", "QA", "RE", "RO", "RS", "RU", "RW", "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SR", "SS", "ST", "SV", "SX", "SY", "SZ", "TC", "TD", "TF", "TG", "TH", "TJ", "TK", "TL", "TM", "TN", "TO", "TR", "TT", "TV", "TW", "TZ", "UA", "UG", "UM", "US", "UY", "UZ", "VA", "VC", "VE", "VG", "VI", "VN", "VU", "WF", "WS", "YE", "YT", "ZA", "ZM", "ZW"}

# See https://github.com/rg3/youtube-dl/blob/master/youtube_dl/extractor/youtube.py#L380-#L476
VIDEO_FORMATS = {
  "5"  => {"ext" => "flv", "width" => 400, "height" => 240, "acodec" => "mp3", "abr" => 64, "vcodec" => "h263"},
  "6"  => {"ext" => "flv", "width" => 450, "height" => 270, "acodec" => "mp3", "abr" => 64, "vcodec" => "h263"},
  "13" => {"ext" => "3gp", "acodec" => "aac", "vcodec" => "mp4v"},
  "17" => {"ext" => "3gp", "width" => 176, "height" => 144, "acodec" => "aac", "abr" => 24, "vcodec" => "mp4v"},
  "18" => {"ext" => "mp4", "width" => 640, "height" => 360, "acodec" => "aac", "abr" => 96, "vcodec" => "h264"},
  "22" => {"ext" => "mp4", "width" => 1280, "height" => 720, "acodec" => "aac", "abr" => 192, "vcodec" => "h264"},
  "34" => {"ext" => "flv", "width" => 640, "height" => 360, "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},
  "35" => {"ext" => "flv", "width" => 854, "height" => 480, "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},

  "36" => {"ext" => "3gp", "width" => 320, "acodec" => "aac", "vcodec" => "mp4v"},
  "37" => {"ext" => "mp4", "width" => 1920, "height" => 1080, "acodec" => "aac", "abr" => 192, "vcodec" => "h264"},
  "38" => {"ext" => "mp4", "width" => 4096, "height" => 3072, "acodec" => "aac", "abr" => 192, "vcodec" => "h264"},
  "43" => {"ext" => "webm", "width" => 640, "height" => 360, "acodec" => "vorbis", "abr" => 128, "vcodec" => "vp8"},
  "44" => {"ext" => "webm", "width" => 854, "height" => 480, "acodec" => "vorbis", "abr" => 128, "vcodec" => "vp8"},
  "45" => {"ext" => "webm", "width" => 1280, "height" => 720, "acodec" => "vorbis", "abr" => 192, "vcodec" => "vp8"},
  "46" => {"ext" => "webm", "width" => 1920, "height" => 1080, "acodec" => "vorbis", "abr" => 192, "vcodec" => "vp8"},
  "59" => {"ext" => "mp4", "width" => 854, "height" => 480, "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},
  "78" => {"ext" => "mp4", "width" => 854, "height" => 480, "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},

  # 3D videos
  "82"  => {"ext" => "mp4", "height" => 360, "format" => "3D", "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},
  "83"  => {"ext" => "mp4", "height" => 480, "format" => "3D", "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},
  "84"  => {"ext" => "mp4", "height" => 720, "format" => "3D", "acodec" => "aac", "abr" => 192, "vcodec" => "h264"},
  "85"  => {"ext" => "mp4", "height" => 1080, "format" => "3D", "acodec" => "aac", "abr" => 192, "vcodec" => "h264"},
  "100" => {"ext" => "webm", "height" => 360, "format" => "3D", "acodec" => "vorbis", "abr" => 128, "vcodec" => "vp8"},
  "101" => {"ext" => "webm", "height" => 480, "format" => "3D", "acodec" => "vorbis", "abr" => 192, "vcodec" => "vp8"},
  "102" => {"ext" => "webm", "height" => 720, "format" => "3D", "acodec" => "vorbis", "abr" => 192, "vcodec" => "vp8"},

  # Apple HTTP Live Streaming
  "91"  => {"ext" => "mp4", "height" => 144, "format" => "HLS", "acodec" => "aac", "abr" => 48, "vcodec" => "h264"},
  "92"  => {"ext" => "mp4", "height" => 240, "format" => "HLS", "acodec" => "aac", "abr" => 48, "vcodec" => "h264"},
  "93"  => {"ext" => "mp4", "height" => 360, "format" => "HLS", "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},
  "94"  => {"ext" => "mp4", "height" => 480, "format" => "HLS", "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},
  "95"  => {"ext" => "mp4", "height" => 720, "format" => "HLS", "acodec" => "aac", "abr" => 256, "vcodec" => "h264"},
  "96"  => {"ext" => "mp4", "height" => 1080, "format" => "HLS", "acodec" => "aac", "abr" => 256, "vcodec" => "h264"},
  "132" => {"ext" => "mp4", "height" => 240, "format" => "HLS", "acodec" => "aac", "abr" => 48, "vcodec" => "h264"},
  "151" => {"ext" => "mp4", "height" => 72, "format" => "HLS", "acodec" => "aac", "abr" => 24, "vcodec" => "h264"},

  # DASH mp4 video
  "133" => {"ext" => "mp4", "height" => 240, "format" => "DASH video", "vcodec" => "h264"},
  "134" => {"ext" => "mp4", "height" => 360, "format" => "DASH video", "vcodec" => "h264"},
  "135" => {"ext" => "mp4", "height" => 480, "format" => "DASH video", "vcodec" => "h264"},
  "136" => {"ext" => "mp4", "height" => 720, "format" => "DASH video", "vcodec" => "h264"},
  "137" => {"ext" => "mp4", "height" => 1080, "format" => "DASH video", "vcodec" => "h264"},
  "138" => {"ext" => "mp4", "format" => "DASH video", "vcodec" => "h264"}, # Height can vary (https://github.com/ytdl-org/youtube-dl/issues/4559)
  "160" => {"ext" => "mp4", "height" => 144, "format" => "DASH video", "vcodec" => "h264"},
  "212" => {"ext" => "mp4", "height" => 480, "format" => "DASH video", "vcodec" => "h264"},
  "264" => {"ext" => "mp4", "height" => 1440, "format" => "DASH video", "vcodec" => "h264"},
  "298" => {"ext" => "mp4", "height" => 720, "format" => "DASH video", "vcodec" => "h264", "fps" => 60},
  "299" => {"ext" => "mp4", "height" => 1080, "format" => "DASH video", "vcodec" => "h264", "fps" => 60},
  "266" => {"ext" => "mp4", "height" => 2160, "format" => "DASH video", "vcodec" => "h264"},

  # Dash mp4 audio
  "139" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "aac", "abr" => 48, "container" => "m4a_dash"},
  "140" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "aac", "abr" => 128, "container" => "m4a_dash"},
  "141" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "aac", "abr" => 256, "container" => "m4a_dash"},
  "256" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "aac", "container" => "m4a_dash"},
  "258" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "aac", "container" => "m4a_dash"},
  "325" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "dtse", "container" => "m4a_dash"},
  "328" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "ec-3", "container" => "m4a_dash"},

  # Dash webm
  "167" => {"ext" => "webm", "height" => 360, "width" => 640, "format" => "DASH video", "container" => "webm", "vcodec" => "vp8"},
  "168" => {"ext" => "webm", "height" => 480, "width" => 854, "format" => "DASH video", "container" => "webm", "vcodec" => "vp8"},
  "169" => {"ext" => "webm", "height" => 720, "width" => 1280, "format" => "DASH video", "container" => "webm", "vcodec" => "vp8"},
  "170" => {"ext" => "webm", "height" => 1080, "width" => 1920, "format" => "DASH video", "container" => "webm", "vcodec" => "vp8"},
  "218" => {"ext" => "webm", "height" => 480, "width" => 854, "format" => "DASH video", "container" => "webm", "vcodec" => "vp8"},
  "219" => {"ext" => "webm", "height" => 480, "width" => 854, "format" => "DASH video", "container" => "webm", "vcodec" => "vp8"},
  "278" => {"ext" => "webm", "height" => 144, "format" => "DASH video", "container" => "webm", "vcodec" => "vp9"},
  "242" => {"ext" => "webm", "height" => 240, "format" => "DASH video", "vcodec" => "vp9"},
  "243" => {"ext" => "webm", "height" => 360, "format" => "DASH video", "vcodec" => "vp9"},
  "244" => {"ext" => "webm", "height" => 480, "format" => "DASH video", "vcodec" => "vp9"},
  "245" => {"ext" => "webm", "height" => 480, "format" => "DASH video", "vcodec" => "vp9"},
  "246" => {"ext" => "webm", "height" => 480, "format" => "DASH video", "vcodec" => "vp9"},
  "247" => {"ext" => "webm", "height" => 720, "format" => "DASH video", "vcodec" => "vp9"},
  "248" => {"ext" => "webm", "height" => 1080, "format" => "DASH video", "vcodec" => "vp9"},
  "271" => {"ext" => "webm", "height" => 1440, "format" => "DASH video", "vcodec" => "vp9"},
  # itag 272 videos are either 3840x2160 (e.g. RtoitU2A-3E) or 7680x4320 (sLprVF6d7Ug)
  "272" => {"ext" => "webm", "height" => 2160, "format" => "DASH video", "vcodec" => "vp9"},
  "302" => {"ext" => "webm", "height" => 720, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
  "303" => {"ext" => "webm", "height" => 1080, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
  "308" => {"ext" => "webm", "height" => 1440, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
  "313" => {"ext" => "webm", "height" => 2160, "format" => "DASH video", "vcodec" => "vp9"},
  "315" => {"ext" => "webm", "height" => 2160, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
  "330" => {"ext" => "webm", "height" => 144, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
  "331" => {"ext" => "webm", "height" => 240, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
  "332" => {"ext" => "webm", "height" => 360, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
  "333" => {"ext" => "webm", "height" => 480, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
  "334" => {"ext" => "webm", "height" => 720, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
  "335" => {"ext" => "webm", "height" => 1080, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
  "336" => {"ext" => "webm", "height" => 1440, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
  "337" => {"ext" => "webm", "height" => 2160, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},

  # Dash webm audio
  "171" => {"ext" => "webm", "acodec" => "vorbis", "format" => "DASH audio", "abr" => 128},
  "172" => {"ext" => "webm", "acodec" => "vorbis", "format" => "DASH audio", "abr" => 256},

  # Dash webm audio with opus inside
  "249" => {"ext" => "webm", "format" => "DASH audio", "acodec" => "opus", "abr" => 50},
  "250" => {"ext" => "webm", "format" => "DASH audio", "acodec" => "opus", "abr" => 70},
  "251" => {"ext" => "webm", "format" => "DASH audio", "acodec" => "opus", "abr" => 160},

  # av01 video only formats sometimes served with "unknown" codecs
  "394" => {"ext" => "mp4", "height" => 144, "vcodec" => "av01.0.05M.08"},
  "395" => {"ext" => "mp4", "height" => 240, "vcodec" => "av01.0.05M.08"},
  "396" => {"ext" => "mp4", "height" => 360, "vcodec" => "av01.0.05M.08"},
  "397" => {"ext" => "mp4", "height" => 480, "vcodec" => "av01.0.05M.08"},
}

struct VideoPreferences
  include JSON::Serializable

  property annotations : Bool
  property autoplay : Bool
  property comments : Array(String)
  property continue : Bool
  property continue_autoplay : Bool
  property controls : Bool
  property listen : Bool
  property local : Bool
  property preferred_captions : Array(String)
  property player_style : String
  property quality : String
  property quality_dash : String
  property raw : Bool
  property region : String?
  property related_videos : Bool
  property speed : Float32 | Float64
  property video_end : Float64 | Int32
  property video_loop : Bool
  property extend_desc : Bool
  property video_start : Float64 | Int32
  property volume : Int32
  property vr_mode : Bool
  property save_player_pos : Bool
end

struct Video
  include DB::Serializable

  property id : String

  @[DB::Field(converter: Video::JSONConverter)]
  property info : Hash(String, JSON::Any)
  property updated : Time

  @[DB::Field(ignore: true)]
  property captions : Array(Caption)?

  @[DB::Field(ignore: true)]
  property adaptive_fmts : Array(Hash(String, JSON::Any))?

  @[DB::Field(ignore: true)]
  property fmt_stream : Array(Hash(String, JSON::Any))?

  @[DB::Field(ignore: true)]
  property description : String?

  module JSONConverter
    def self.from_rs(rs)
      JSON.parse(rs.read(String)).as_h
    end
  end

  def to_json(locale : String?, json : JSON::Builder)
    json.object do
      json.field "type", "video"

      json.field "title", self.title
      json.field "videoId", self.id

      json.field "error", info["reason"] if info["reason"]?

      json.field "videoThumbnails" do
        generate_thumbnails(json, self.id)
      end
      json.field "storyboards" do
        generate_storyboards(json, self.id, self.storyboards)
      end

      json.field "description", self.description
      json.field "descriptionHtml", self.description_html
      json.field "published", self.published.to_unix
      json.field "publishedText", translate(locale, "`x` ago", recode_date(self.published, locale))
      json.field "keywords", self.keywords

      json.field "viewCount", self.views
      json.field "likeCount", self.likes
      json.field "dislikeCount", self.dislikes

      json.field "paid", self.paid
      json.field "premium", self.premium
      json.field "isFamilyFriendly", self.is_family_friendly
      json.field "allowedRegions", self.allowed_regions
      json.field "genre", self.genre
      json.field "genreUrl", self.genre_url

      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", "/channel/#{self.ucid}"

      json.field "authorThumbnails" do
        json.array do
          qualities = {32, 48, 76, 100, 176, 512}

          qualities.each do |quality|
            json.object do
              json.field "url", self.author_thumbnail.gsub(/=s\d+/, "=s#{quality}")
              json.field "width", quality
              json.field "height", quality
            end
          end
        end
      end

      json.field "subCountText", self.sub_count_text

      json.field "lengthSeconds", self.length_seconds
      json.field "allowRatings", self.allow_ratings
      json.field "rating", self.average_rating
      json.field "isListed", self.is_listed
      json.field "liveNow", self.live_now
      json.field "isUpcoming", self.is_upcoming

      if self.premiere_timestamp
        json.field "premiereTimestamp", self.premiere_timestamp.try &.to_unix
      end

      if hlsvp = self.hls_manifest_url
        hlsvp = hlsvp.gsub("https://manifest.googlevideo.com", HOST_URL)
        json.field "hlsUrl", hlsvp
      end

      json.field "dashUrl", "#{HOST_URL}/api/manifest/dash/id/#{id}"

      json.field "adaptiveFormats" do
        json.array do
          self.adaptive_fmts.each do |fmt|
            json.object do
              # Only available on regular videos, not livestreams/OTF streams
              if init_range = fmt["initRange"]?
                json.field "init", "#{init_range["start"]}-#{init_range["end"]}"
              end
              if index_range = fmt["indexRange"]?
                json.field "index", "#{index_range["start"]}-#{index_range["end"]}"
              end

              # Not available on MPEG-4 Timed Text (`text/mp4`) streams (livestreams only)
              json.field "bitrate", fmt["bitrate"].as_i.to_s if fmt["bitrate"]?

              json.field "url", fmt["url"]
              json.field "itag", fmt["itag"].as_i.to_s
              json.field "type", fmt["mimeType"]
              json.field "clen", fmt["contentLength"]? || "-1"
              json.field "lmt", fmt["lastModified"]
              json.field "projectionType", fmt["projectionType"]

              if fmt_info = itag_to_metadata?(fmt["itag"])
                fps = fmt_info["fps"]?.try &.to_i || fmt["fps"]?.try &.as_i || 30
                json.field "fps", fps
                json.field "container", fmt_info["ext"]
                json.field "encoding", fmt_info["vcodec"]? || fmt_info["acodec"]

                if fmt_info["height"]?
                  json.field "resolution", "#{fmt_info["height"]}p"

                  quality_label = "#{fmt_info["height"]}p"
                  if fps > 30
                    quality_label += "60"
                  end
                  json.field "qualityLabel", quality_label

                  if fmt_info["width"]?
                    json.field "size", "#{fmt_info["width"]}x#{fmt_info["height"]}"
                  end
                end
              end

              # Livestream chunk infos
              json.field "targetDurationSec", fmt["targetDurationSec"].as_i if fmt.has_key?("targetDurationSec")
              json.field "maxDvrDurationSec", fmt["maxDvrDurationSec"].as_i if fmt.has_key?("maxDvrDurationSec")

              # Audio-related data
              json.field "audioQuality", fmt["audioQuality"] if fmt.has_key?("audioQuality")
              json.field "audioSampleRate", fmt["audioSampleRate"].as_s.to_i if fmt.has_key?("audioSampleRate")
              json.field "audioChannels", fmt["audioChannels"] if fmt.has_key?("audioChannels")

              # Extra misc stuff
              json.field "colorInfo", fmt["colorInfo"] if fmt.has_key?("colorInfo")
              json.field "captionTrack", fmt["captionTrack"] if fmt.has_key?("captionTrack")
            end
          end
        end
      end

      json.field "formatStreams" do
        json.array do
          self.fmt_stream.each do |fmt|
            json.object do
              json.field "url", fmt["url"]
              json.field "itag", fmt["itag"].as_i.to_s
              json.field "type", fmt["mimeType"]
              json.field "quality", fmt["quality"]

              fmt_info = itag_to_metadata?(fmt["itag"])
              if fmt_info
                fps = fmt_info["fps"]?.try &.to_i || fmt["fps"]?.try &.as_i || 30
                json.field "fps", fps
                json.field "container", fmt_info["ext"]
                json.field "encoding", fmt_info["vcodec"]? || fmt_info["acodec"]

                if fmt_info["height"]?
                  json.field "resolution", "#{fmt_info["height"]}p"

                  quality_label = "#{fmt_info["height"]}p"
                  if fps > 30
                    quality_label += "60"
                  end
                  json.field "qualityLabel", quality_label

                  if fmt_info["width"]?
                    json.field "size", "#{fmt_info["width"]}x#{fmt_info["height"]}"
                  end
                end
              end
            end
          end
        end
      end

      json.field "captions" do
        json.array do
          self.captions.each do |caption|
            json.object do
              json.field "label", caption.name
              json.field "language_code", caption.language_code
              json.field "url", "/api/v1/captions/#{id}?label=#{URI.encode_www_form(caption.name)}"
            end
          end
        end
      end

      json.field "recommendedVideos" do
        json.array do
          self.related_videos.each do |rv|
            if rv["id"]?
              json.object do
                json.field "videoId", rv["id"]
                json.field "title", rv["title"]
                json.field "videoThumbnails" do
                  generate_thumbnails(json, rv["id"])
                end

                json.field "author", rv["author"]
                json.field "authorUrl", "/channel/#{rv["ucid"]?}"
                json.field "authorId", rv["ucid"]?
                if rv["author_thumbnail"]?
                  json.field "authorThumbnails" do
                    json.array do
                      qualities = {32, 48, 76, 100, 176, 512}

                      qualities.each do |quality|
                        json.object do
                          json.field "url", rv["author_thumbnail"].gsub(/s\d+-/, "s#{quality}-")
                          json.field "width", quality
                          json.field "height", quality
                        end
                      end
                    end
                  end
                end

                json.field "lengthSeconds", rv["length_seconds"]?.try &.to_i
                json.field "viewCountText", rv["short_view_count"]?
                json.field "viewCount", rv["view_count"]?.try &.empty? ? nil : rv["view_count"].to_i64
              end
            end
          end
        end
      end
    end
  end

  # TODO: remove the locale and follow the crystal convention
  def to_json(locale : String?, _json : Nil)
    JSON.build { |json| to_json(locale, json) }
  end

  def to_json(json : JSON::Builder | Nil = nil)
    to_json(nil, json)
  end

  def title
    info["videoDetails"]["title"]?.try &.as_s || ""
  end

  def ucid
    info["videoDetails"]["channelId"]?.try &.as_s || ""
  end

  def author
    info["videoDetails"]["author"]?.try &.as_s || ""
  end

  def length_seconds : Int32
    info.dig?("microformat", "playerMicroformatRenderer", "lengthSeconds").try &.as_s.to_i ||
      info["videoDetails"]["lengthSeconds"]?.try &.as_s.to_i || 0
  end

  def views : Int64
    info["videoDetails"]["viewCount"]?.try &.as_s.to_i64 || 0_i64
  end

  def likes : Int64
    info["likes"]?.try &.as_i64 || 0_i64
  end

  def dislikes : Int64
    info["dislikes"]?.try &.as_i64 || 0_i64
  end

  def average_rating : Float64
    # (likes / (likes + dislikes) * 4 + 1)
    info["videoDetails"]["averageRating"]?.try { |t| t.as_f? || t.as_i64?.try &.to_f64 }.try &.round(4) || 0.0
  end

  def published : Time
    info
      .dig?("microformat", "playerMicroformatRenderer", "publishDate")
      .try { |t| Time.parse(t.as_s, "%Y-%m-%d", Time::Location::UTC) } || Time.utc
  end

  def published=(other : Time)
    info["microformat"].as_h["playerMicroformatRenderer"].as_h["publishDate"] = JSON::Any.new(other.to_s("%Y-%m-%d"))
  end

  def allow_ratings
    r = info["videoDetails"]["allowRatings"]?.try &.as_bool
    r.nil? ? false : r
  end

  def live_now
    info["microformat"]?.try &.["playerMicroformatRenderer"]?
      .try &.["liveBroadcastDetails"]?.try &.["isLiveNow"]?.try &.as_bool || false
  end

  def is_listed
    info["videoDetails"]["isCrawlable"]?.try &.as_bool || false
  end

  def is_upcoming
    info["videoDetails"]["isUpcoming"]?.try &.as_bool || false
  end

  def premiere_timestamp : Time?
    info
      .dig?("microformat", "playerMicroformatRenderer", "liveBroadcastDetails", "startTimestamp")
      .try { |t| Time.parse_rfc3339(t.as_s) }
  end

  def keywords
    info["videoDetails"]["keywords"]?.try &.as_a.map &.as_s || [] of String
  end

  def related_videos
    info["relatedVideos"]?.try &.as_a.map { |h| h.as_h.transform_values &.as_s } || [] of Hash(String, String)
  end

  def allowed_regions
    info
      .dig?("microformat", "playerMicroformatRenderer", "availableCountries")
      .try &.as_a.map &.as_s || [] of String
  end

  def author_thumbnail : String
    info["authorThumbnail"]?.try &.as_s || ""
  end

  def author_verified : Bool
    info["authorVerified"]?.try &.as_bool || false
  end

  def sub_count_text : String
    info["subCountText"]?.try &.as_s || "-"
  end

  def fmt_stream
    return @fmt_stream.as(Array(Hash(String, JSON::Any))) if @fmt_stream

    fmt_stream = info["streamingData"]?.try &.["formats"]?.try &.as_a.map &.as_h || [] of Hash(String, JSON::Any)
    fmt_stream.each do |fmt|
      if s = (fmt["cipher"]? || fmt["signatureCipher"]?).try { |h| HTTP::Params.parse(h.as_s) }
        s.each do |k, v|
          fmt[k] = JSON::Any.new(v)
        end
        fmt["url"] = JSON::Any.new("#{fmt["url"]}#{DECRYPT_FUNCTION.decrypt_signature(fmt)}")
      end

      fmt["url"] = JSON::Any.new("#{fmt["url"]}&host=#{URI.parse(fmt["url"].as_s).host}")
      fmt["url"] = JSON::Any.new("#{fmt["url"]}&region=#{self.info["region"]}") if self.info["region"]?
    end

    fmt_stream.sort_by! { |f| f["width"]?.try &.as_i || 0 }
    @fmt_stream = fmt_stream
    return @fmt_stream.as(Array(Hash(String, JSON::Any)))
  end

  def adaptive_fmts
    return @adaptive_fmts.as(Array(Hash(String, JSON::Any))) if @adaptive_fmts
    fmt_stream = info["streamingData"]?.try &.["adaptiveFormats"]?.try &.as_a.map &.as_h || [] of Hash(String, JSON::Any)
    fmt_stream.each do |fmt|
      if s = (fmt["cipher"]? || fmt["signatureCipher"]?).try { |h| HTTP::Params.parse(h.as_s) }
        s.each do |k, v|
          fmt[k] = JSON::Any.new(v)
        end
        fmt["url"] = JSON::Any.new("#{fmt["url"]}#{DECRYPT_FUNCTION.decrypt_signature(fmt)}")
      end

      fmt["url"] = JSON::Any.new("#{fmt["url"]}&host=#{URI.parse(fmt["url"].as_s).host}")
      fmt["url"] = JSON::Any.new("#{fmt["url"]}&region=#{self.info["region"]}") if self.info["region"]?
    end

    fmt_stream.sort_by! { |f| f["width"]?.try &.as_i || 0 }
    @adaptive_fmts = fmt_stream
    return @adaptive_fmts.as(Array(Hash(String, JSON::Any)))
  end

  def video_streams
    adaptive_fmts.select &.["mimeType"]?.try &.as_s.starts_with?("video")
  end

  def audio_streams
    adaptive_fmts.select &.["mimeType"]?.try &.as_s.starts_with?("audio")
  end

  def storyboards
    storyboards = info.dig?("storyboards", "playerStoryboardSpecRenderer", "spec")
      .try &.as_s.split("|")

    if !storyboards
      if storyboard = info.dig?("storyboards", "playerLiveStoryboardSpecRenderer", "spec").try &.as_s
        return [{
          url:               storyboard.split("#")[0],
          width:             106,
          height:            60,
          count:             -1,
          interval:          5000,
          storyboard_width:  3,
          storyboard_height: 3,
          storyboard_count:  -1,
        }]
      end
    end

    items = [] of NamedTuple(
      url: String,
      width: Int32,
      height: Int32,
      count: Int32,
      interval: Int32,
      storyboard_width: Int32,
      storyboard_height: Int32,
      storyboard_count: Int32)

    return items if !storyboards

    url = URI.parse(storyboards.shift)
    params = HTTP::Params.parse(url.query || "")

    storyboards.each_with_index do |sb, i|
      width, height, count, storyboard_width, storyboard_height, interval, _, sigh = sb.split("#")
      params["sigh"] = sigh
      url.query = params.to_s

      width = width.to_i
      height = height.to_i
      count = count.to_i
      interval = interval.to_i
      storyboard_width = storyboard_width.to_i
      storyboard_height = storyboard_height.to_i
      storyboard_count = (count / (storyboard_width * storyboard_height)).ceil.to_i

      items << {
        url:               url.to_s.sub("$L", i).sub("$N", "M$M"),
        width:             width,
        height:            height,
        count:             count,
        interval:          interval,
        storyboard_width:  storyboard_width,
        storyboard_height: storyboard_height,
        storyboard_count:  storyboard_count,
      }
    end

    items
  end

  def paid
    reason = info.dig?("playabilityStatus", "reason").try &.as_s || ""
    return reason.includes? "requires payment"
  end

  def premium
    keywords.includes? "YouTube Red"
  end

  def captions : Array(Caption)
    return @captions.as(Array(Caption)) if @captions
    captions = info["captions"]?.try &.["playerCaptionsTracklistRenderer"]?.try &.["captionTracks"]?.try &.as_a.map do |caption|
      name = caption["name"]["simpleText"]? || caption["name"]["runs"][0]["text"]
      language_code = caption["languageCode"].to_s
      base_url = caption["baseUrl"].to_s

      caption = Caption.new(name.to_s, language_code, base_url)
      caption.name = caption.name.split(" - ")[0]
      caption
    end
    captions ||= [] of Caption
    @captions = captions
    return @captions.as(Array(Caption))
  end

  def description
    description = info
      .dig?("microformat", "playerMicroformatRenderer", "description", "simpleText")
      .try &.as_s || ""
  end

  # TODO
  def description=(value : String)
    @description = value
  end

  def description_html
    info["descriptionHtml"]?.try &.as_s || "<p></p>"
  end

  def description_html=(value : String)
    info["descriptionHtml"] = JSON::Any.new(value)
  end

  def short_description
    info["shortDescription"]?.try &.as_s? || ""
  end

  def hls_manifest_url : String?
    info.dig?("streamingData", "hlsManifestUrl").try &.as_s
  end

  def dash_manifest_url
    info.dig?("streamingData", "dashManifestUrl").try &.as_s
  end

  def genre : String
    info["genre"]?.try &.as_s || ""
  end

  def genre_url : String?
    info["genreUcid"]? ? "/channel/#{info["genreUcid"]}" : nil
  end

  def license : String?
    info["license"]?.try &.as_s
  end

  def is_family_friendly : Bool
    info.dig?("microformat", "playerMicroformatRenderer", "isFamilySafe").try &.as_bool || false
  end

  def is_vr : Bool?
    projection_type = info.dig?("streamingData", "adaptiveFormats", 0, "projectionType").try &.as_s
    return {"EQUIRECTANGULAR", "MESH"}.includes? projection_type
  end

  def projection_type : String?
    return info.dig?("streamingData", "adaptiveFormats", 0, "projectionType").try &.as_s
  end

  def wilson_score : Float64
    ci_lower_bound(likes, likes + dislikes).round(4)
  end

  def engagement : Float64
    (((likes + dislikes) / views) * 100).round(4)
  end

  def reason : String?
    info["reason"]?.try &.as_s
  end
end

struct Caption
  property name
  property language_code
  property base_url

  getter name : String
  getter language_code : String
  getter base_url : String

  setter name

  def initialize(@name, @language_code, @base_url)
  end
end

class VideoRedirect < Exception
  property video_id : String

  def initialize(@video_id)
  end
end

# Use to parse both "compactVideoRenderer" and "endScreenVideoRenderer".
# The former is preferred as it has more videos in it. The second has
# the same 11 first entries as the compact rendered.
#
# TODO: "compactRadioRenderer" (Mix) and
def parse_related_video(related : JSON::Any) : Hash(String, JSON::Any)?
  return nil if !related["videoId"]?

  # The compact renderer has video length in seconds, where the end
  # screen rendered has a full text version ("42:40")
  length = related["lengthInSeconds"]?.try &.as_i.to_s
  length ||= related.dig?("lengthText", "simpleText").try do |box|
    decode_length_seconds(box.as_s).to_s
  end

  # Both have "short", so the "long" option shouldn't be required
  channel_info = (related["shortBylineText"]? || related["longBylineText"]?)
    .try &.dig?("runs", 0)

  author = channel_info.try &.dig?("text")
  author_verified_badge = related["ownerBadges"]?.try do |badges_array|
    badges_array.as_a.find(&.dig("metadataBadgeRenderer", "tooltip").as_s.== "Verified")
  end

  author_verified = (author_verified_badge && author_verified_badge.size > 0).to_s

  ucid = channel_info.try { |ci| HelperExtractors.get_browse_id(ci) }

  # "4,088,033 views", only available on compact renderer
  # and when video is not a livestream
  view_count = related.dig?("viewCountText", "simpleText")
    .try &.as_s.gsub(/\D/, "")

  short_view_count = related.try do |r|
    HelperExtractors.get_short_view_count(r).to_s
  end

  LOGGER.trace("parse_related_video: Found \"watchNextEndScreenRenderer\" container")

  # TODO: when refactoring video types, make a struct for related videos
  # or reuse an existing type, if that fits.
  return {
    "id"               => related["videoId"],
    "title"            => related["title"]["simpleText"],
    "author"           => author || JSON::Any.new(""),
    "ucid"             => JSON::Any.new(ucid || ""),
    "length_seconds"   => JSON::Any.new(length || "0"),
    "view_count"       => JSON::Any.new(view_count || "0"),
    "short_view_count" => JSON::Any.new(short_view_count || "0"),
    "author_verified"  => JSON::Any.new(author_verified),
  }
end

def extract_video_info(video_id : String, proxy_region : String? = nil, context_screen : String? = nil)
  params = {} of String => JSON::Any

  client_config = YoutubeAPI::ClientConfig.new(proxy_region: proxy_region)
  if context_screen == "embed"
    client_config.client_type = YoutubeAPI::ClientType::TvHtml5ScreenEmbed
  end

  player_response = YoutubeAPI.player(video_id: video_id, params: "", client_config: client_config)

  if player_response.dig?("playabilityStatus", "status").try &.as_s != "OK"
    subreason = player_response.dig?("playabilityStatus", "errorScreen", "playerErrorMessageRenderer", "subreason")
    reason = subreason.try &.[]?("simpleText").try &.as_s
    reason ||= subreason.try &.[]("runs").as_a.map(&.[]("text")).join("")
    reason ||= player_response.dig("playabilityStatus", "reason").as_s
    params["reason"] = JSON::Any.new(reason)
    return params
  end

  params["shortDescription"] = player_response.dig?("videoDetails", "shortDescription") || JSON::Any.new(nil)

  # Don't fetch the next endpoint if the video is unavailable.
  if !params["reason"]?
    next_response = YoutubeAPI.next({"videoId": video_id, "params": ""})
    player_response = player_response.merge(next_response)
  end

  # Fetch the video streams using an Android client in order to get the decrypted URLs and
  # maybe fix throttling issues (#2194).See for the explanation about the decrypted URLs:
  # https://github.com/TeamNewPipe/NewPipeExtractor/issues/562
  if !params["reason"]?
    if context_screen == "embed"
      client_config.client_type = YoutubeAPI::ClientType::AndroidScreenEmbed
    else
      client_config.client_type = YoutubeAPI::ClientType::Android
    end
    android_player = YoutubeAPI.player(video_id: video_id, params: "", client_config: client_config)

    # Sometime, the video is available from the web client, but not on Android, so check
    # that here, and fallback to the streaming data from the web client if needed.
    # See: https://github.com/iv-org/invidious/issues/2549
    if android_player["playabilityStatus"]["status"] == "OK"
      params["streamingData"] = android_player["streamingData"]? || JSON::Any.new("")
    else
      params["streamingData"] = player_response["streamingData"]? || JSON::Any.new("")
    end
  end

  {"captions", "microformat", "playabilityStatus", "storyboards", "videoDetails"}.each do |f|
    params[f] = player_response[f] if player_response[f]?
  end

  # Top level elements

  main_results = player_response.dig?("contents", "twoColumnWatchNextResults")

  raise BrokenTubeException.new("twoColumnWatchNextResults") if !main_results

  primary_results = main_results.dig?("results", "results", "contents")

  raise BrokenTubeException.new("results") if !primary_results

  video_primary_renderer = primary_results
    .as_a.find(&.["videoPrimaryInfoRenderer"]?)
    .try &.["videoPrimaryInfoRenderer"]

  video_secondary_renderer = primary_results
    .as_a.find(&.["videoSecondaryInfoRenderer"]?)
    .try &.["videoSecondaryInfoRenderer"]

  raise BrokenTubeException.new("videoPrimaryInfoRenderer") if !video_primary_renderer
  raise BrokenTubeException.new("videoSecondaryInfoRenderer") if !video_secondary_renderer

  # Related videos

  LOGGER.debug("extract_video_info: parsing related videos...")

  related = [] of JSON::Any

  # Parse "compactVideoRenderer" items (under secondary results)
  secondary_results = main_results
    .dig?("secondaryResults", "secondaryResults", "results")
  secondary_results.try &.as_a.each do |element|
    if item = element["compactVideoRenderer"]?
      related_video = parse_related_video(item)
      related << JSON::Any.new(related_video) if related_video
    end
  end

  # If nothing was found previously, fall back to end screen renderer
  if related.empty?
    # Container for "endScreenVideoRenderer" items
    player_overlays = player_response.dig?(
      "playerOverlays", "playerOverlayRenderer",
      "endScreen", "watchNextEndScreenRenderer", "results"
    )

    player_overlays.try &.as_a.each do |element|
      if item = element["endScreenVideoRenderer"]?
        related_video = parse_related_video(item)
        related << JSON::Any.new(related_video) if related_video
      end
    end
  end

  params["relatedVideos"] = JSON::Any.new(related)

  # Likes/dislikes

  toplevel_buttons = video_primary_renderer
    .try &.dig?("videoActions", "menuRenderer", "topLevelButtons")

  if toplevel_buttons
    likes_button = toplevel_buttons.as_a
      .find(&.dig("toggleButtonRenderer", "defaultIcon", "iconType").as_s.== "LIKE")
      .try &.["toggleButtonRenderer"]

    if likes_button
      likes_txt = (likes_button["defaultText"]? || likes_button["toggledText"]?)
        .try &.dig?("accessibility", "accessibilityData", "label")
      likes = likes_txt.as_s.gsub(/\D/, "").to_i64? if likes_txt

      LOGGER.trace("extract_video_info: Found \"likes\" button. Button text is \"#{likes_txt}\"")
      LOGGER.debug("extract_video_info: Likes count is #{likes}") if likes
    end

    dislikes_button = toplevel_buttons.as_a
      .find(&.dig("toggleButtonRenderer", "defaultIcon", "iconType").as_s.== "DISLIKE")
      .try &.["toggleButtonRenderer"]

    if dislikes_button
      dislikes_txt = (dislikes_button["defaultText"]? || dislikes_button["toggledText"]?)
        .try &.dig?("accessibility", "accessibilityData", "label")
      dislikes = dislikes_txt.as_s.gsub(/\D/, "").to_i64? if dislikes_txt

      LOGGER.trace("extract_video_info: Found \"dislikes\" button. Button text is \"#{dislikes_txt}\"")
      LOGGER.debug("extract_video_info: Dislikes count is #{dislikes}") if dislikes
    end
  end

  if likes && likes != 0_i64 && (!dislikes || dislikes == 0_i64)
    if rating = player_response.dig?("videoDetails", "averageRating").try { |x| x.as_i64? || x.as_f? }
      dislikes = (likes * ((5 - rating)/(rating - 1))).round.to_i64
      LOGGER.debug("extract_video_info: Dislikes count (using fallback method) is #{dislikes}")
    end
  end

  params["likes"] = JSON::Any.new(likes || 0_i64)
  params["dislikes"] = JSON::Any.new(dislikes || 0_i64)

  # Description

  description_html = video_secondary_renderer.try &.dig?("description", "runs")
    .try &.as_a.try { |t| content_to_comment_html(t, video_id) }

  params["descriptionHtml"] = JSON::Any.new(description_html || "<p></p>")

  # Video metadata

  metadata = video_secondary_renderer
    .try &.dig?("metadataRowContainer", "metadataRowContainerRenderer", "rows")
      .try &.as_a

  params["genre"] = params["microformat"]?.try &.["playerMicroformatRenderer"]?.try &.["category"]? || JSON::Any.new("")
  params["genreUrl"] = JSON::Any.new(nil)

  metadata.try &.each do |row|
    title = row["metadataRowRenderer"]?.try &.["title"]?.try &.["simpleText"]?.try &.as_s
    contents = row.dig?("metadataRowRenderer", "contents", 0)

    if title.try &.== "Category"
      contents = contents.try &.dig?("runs", 0)

      params["genre"] = JSON::Any.new(contents.try &.["text"]?.try &.as_s || "")
      params["genreUcid"] = JSON::Any.new(contents.try &.["navigationEndpoint"]?.try &.["browseEndpoint"]?
        .try &.["browseId"]?.try &.as_s || "")
    elsif title.try &.== "License"
      contents = contents.try &.["runs"]?
        .try &.as_a[0]?

      params["license"] = JSON::Any.new(contents.try &.["text"]?.try &.as_s || "")
    elsif title.try &.== "Licensed to YouTube by"
      params["license"] = JSON::Any.new(contents.try &.["simpleText"]?.try &.as_s || "")
    end
  end

  # Author infos

  author_info = video_secondary_renderer.try &.dig?("owner", "videoOwnerRenderer")
  author_thumbnail = author_info.try &.dig?("thumbnail", "thumbnails", 0, "url")

  author_verified_badge = author_info.try &.dig?("badges", 0, "metadataBadgeRenderer", "tooltip")
  author_verified = (!author_verified_badge.nil? && author_verified_badge == "Verified")
  params["authorVerified"] = JSON::Any.new(author_verified)

  params["authorThumbnail"] = JSON::Any.new(author_thumbnail.try &.as_s || "")

  params["subCountText"] = JSON::Any.new(author_info.try &.["subscriberCountText"]?
    .try { |t| t["simpleText"]? || t.dig?("runs", 0, "text") }.try &.as_s.split(" ", 2)[0] || "-")

  # Return data

  return params
end

def get_video(id, refresh = true, region = nil, force_refresh = false)
  if (video = Invidious::Database::Videos.select(id)) && !region
    # If record was last updated over 10 minutes ago, or video has since premiered,
    # refresh (expire param in response lasts for 6 hours)
    if (refresh &&
       (Time.utc - video.updated > 10.minutes) ||
       (video.premiere_timestamp.try &.< Time.utc)) ||
       force_refresh
      begin
        video = fetch_video(id, region)
        Invidious::Database::Videos.update(video)
      rescue ex
        Invidious::Database::Videos.delete(id)
        raise ex
      end
    end
  else
    video = fetch_video(id, region)
    Invidious::Database::Videos.insert(video) if !region
  end

  return video
rescue DB::Error
  # Avoid common `DB::PoolRetryAttemptsExceeded` error and friends
  # Note: All DB errors inherit from `DB::Error`
  return fetch_video(id, region)
end

def fetch_video(id, region)
  info = extract_video_info(video_id: id)

  allowed_regions = info
    .dig?("microformat", "playerMicroformatRenderer", "availableCountries")
    .try &.as_a.map &.as_s || [] of String

  # Check for region-blocks
  if info["reason"]?.try &.as_s.includes?("your country")
    bypass_regions = PROXY_LIST.keys & allowed_regions
    if !bypass_regions.empty?
      region = bypass_regions[rand(bypass_regions.size)]
      region_info = extract_video_info(video_id: id, proxy_region: region)
      region_info["region"] = JSON::Any.new(region) if region
      info = region_info if !region_info["reason"]?
    end
  end

  # Try to fetch video info using an embedded client
  if info["reason"]?
    embed_info = extract_video_info(video_id: id, context_screen: "embed")
    info = embed_info if !embed_info["reason"]?
  end

  if reason = info["reason"]?
    raise InfoException.new(reason.as_s || "")
  end

  video = Video.new({
    id:      id,
    info:    info,
    updated: Time.utc,
  })

  return video
end

def itag_to_metadata?(itag : JSON::Any)
  return VIDEO_FORMATS[itag.to_s]?
end

def process_continuation(query, plid, id)
  continuation = nil
  if plid
    if index = query["index"]?.try &.to_i?
      continuation = index
    else
      continuation = id
    end
    continuation ||= 0
  end

  continuation
end

def process_video_params(query, preferences)
  annotations = query["iv_load_policy"]?.try &.to_i?
  autoplay = query["autoplay"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  comments = query["comments"]?.try &.split(",").map(&.downcase)
  continue = query["continue"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  continue_autoplay = query["continue_autoplay"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  listen = query["listen"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  local = query["local"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  player_style = query["player_style"]?
  preferred_captions = query["subtitles"]?.try &.split(",").map(&.downcase)
  quality = query["quality"]?
  quality_dash = query["quality_dash"]?
  region = query["region"]?
  related_videos = query["related_videos"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  speed = query["speed"]?.try &.rchop("x").to_f?
  video_loop = query["loop"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  extend_desc = query["extend_desc"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  volume = query["volume"]?.try &.to_i?
  vr_mode = query["vr_mode"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  save_player_pos = query["save_player_pos"]?.try { |q| (q == "true" || q == "1").to_unsafe }

  if preferences
    # region ||= preferences.region
    annotations ||= preferences.annotations.to_unsafe
    autoplay ||= preferences.autoplay.to_unsafe
    comments ||= preferences.comments
    continue ||= preferences.continue.to_unsafe
    continue_autoplay ||= preferences.continue_autoplay.to_unsafe
    listen ||= preferences.listen.to_unsafe
    local ||= preferences.local.to_unsafe
    player_style ||= preferences.player_style
    preferred_captions ||= preferences.captions
    quality ||= preferences.quality
    quality_dash ||= preferences.quality_dash
    related_videos ||= preferences.related_videos.to_unsafe
    speed ||= preferences.speed
    video_loop ||= preferences.video_loop.to_unsafe
    extend_desc ||= preferences.extend_desc.to_unsafe
    volume ||= preferences.volume
    vr_mode ||= preferences.vr_mode.to_unsafe
    save_player_pos ||= preferences.save_player_pos.to_unsafe
  end

  annotations ||= CONFIG.default_user_preferences.annotations.to_unsafe
  autoplay ||= CONFIG.default_user_preferences.autoplay.to_unsafe
  comments ||= CONFIG.default_user_preferences.comments
  continue ||= CONFIG.default_user_preferences.continue.to_unsafe
  continue_autoplay ||= CONFIG.default_user_preferences.continue_autoplay.to_unsafe
  listen ||= CONFIG.default_user_preferences.listen.to_unsafe
  local ||= CONFIG.default_user_preferences.local.to_unsafe
  player_style ||= CONFIG.default_user_preferences.player_style
  preferred_captions ||= CONFIG.default_user_preferences.captions
  quality ||= CONFIG.default_user_preferences.quality
  quality_dash ||= CONFIG.default_user_preferences.quality_dash
  related_videos ||= CONFIG.default_user_preferences.related_videos.to_unsafe
  speed ||= CONFIG.default_user_preferences.speed
  video_loop ||= CONFIG.default_user_preferences.video_loop.to_unsafe
  extend_desc ||= CONFIG.default_user_preferences.extend_desc.to_unsafe
  volume ||= CONFIG.default_user_preferences.volume
  vr_mode ||= CONFIG.default_user_preferences.vr_mode.to_unsafe
  save_player_pos ||= CONFIG.default_user_preferences.save_player_pos.to_unsafe

  annotations = annotations == 1
  autoplay = autoplay == 1
  continue = continue == 1
  continue_autoplay = continue_autoplay == 1
  listen = listen == 1
  local = local == 1
  related_videos = related_videos == 1
  video_loop = video_loop == 1
  extend_desc = extend_desc == 1
  vr_mode = vr_mode == 1
  save_player_pos = save_player_pos == 1

  if CONFIG.disabled?("dash") && quality == "dash"
    quality = "high"
  end

  if CONFIG.disabled?("local") && local
    local = false
  end

  if start = query["t"]? || query["time_continue"]? || query["start"]?
    video_start = decode_time(start)
  end
  video_start ||= 0

  if query["end"]?
    video_end = decode_time(query["end"])
  end
  video_end ||= -1

  raw = query["raw"]?.try &.to_i?
  raw ||= 0
  raw = raw == 1

  controls = query["controls"]?.try &.to_i?
  controls ||= 1
  controls = controls >= 1

  params = VideoPreferences.new({
    annotations:        annotations,
    autoplay:           autoplay,
    comments:           comments,
    continue:           continue,
    continue_autoplay:  continue_autoplay,
    controls:           controls,
    listen:             listen,
    local:              local,
    player_style:       player_style,
    preferred_captions: preferred_captions,
    quality:            quality,
    quality_dash:       quality_dash,
    raw:                raw,
    region:             region,
    related_videos:     related_videos,
    speed:              speed,
    video_end:          video_end,
    video_loop:         video_loop,
    extend_desc:        extend_desc,
    video_start:        video_start,
    volume:             volume,
    vr_mode:            vr_mode,
    save_player_pos:    save_player_pos,
  })

  return params
end

def build_thumbnails(id)
  return {
    {host: HOST_URL, height: 720, width: 1280, name: "maxres", url: "maxres"},
    {host: HOST_URL, height: 720, width: 1280, name: "maxresdefault", url: "maxresdefault"},
    {host: HOST_URL, height: 480, width: 640, name: "sddefault", url: "sddefault"},
    {host: HOST_URL, height: 360, width: 480, name: "high", url: "hqdefault"},
    {host: HOST_URL, height: 180, width: 320, name: "medium", url: "mqdefault"},
    {host: HOST_URL, height: 90, width: 120, name: "default", url: "default"},
    {host: HOST_URL, height: 90, width: 120, name: "start", url: "1"},
    {host: HOST_URL, height: 90, width: 120, name: "middle", url: "2"},
    {host: HOST_URL, height: 90, width: 120, name: "end", url: "3"},
  }
end

def generate_thumbnails(json, id)
  json.array do
    build_thumbnails(id).each do |thumbnail|
      json.object do
        json.field "quality", thumbnail[:name]
        json.field "url", "#{thumbnail[:host]}/vi/#{id}/#{thumbnail["url"]}.jpg"
        json.field "width", thumbnail[:width]
        json.field "height", thumbnail[:height]
      end
    end
  end
end

def generate_storyboards(json, id, storyboards)
  json.array do
    storyboards.each do |storyboard|
      json.object do
        json.field "url", "/api/v1/storyboards/#{id}?width=#{storyboard[:width]}&height=#{storyboard[:height]}"
        json.field "templateUrl", storyboard[:url]
        json.field "width", storyboard[:width]
        json.field "height", storyboard[:height]
        json.field "count", storyboard[:count]
        json.field "interval", storyboard[:interval]
        json.field "storyboardWidth", storyboard[:storyboard_width]
        json.field "storyboardHeight", storyboard[:storyboard_height]
        json.field "storyboardCount", storyboard[:storyboard_count]
      end
    end
  end
end
