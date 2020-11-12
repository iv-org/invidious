CAPTION_LANGUAGES = {
  "",
  "English",
  "English (auto-generated)",
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
  "Catalan",
  "Cebuano",
  "Chinese (Simplified)",
  "Chinese (Traditional)",
  "Corsican",
  "Croatian",
  "Czech",
  "Danish",
  "Dutch",
  "Esperanto",
  "Estonian",
  "Filipino",
  "Finnish",
  "French",
  "Galician",
  "Georgian",
  "German",
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
  "Irish",
  "Italian",
  "Japanese",
  "Javanese",
  "Kannada",
  "Kazakh",
  "Khmer",
  "Korean",
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
  "Punjabi",
  "Romanian",
  "Russian",
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
  "Spanish (Latin America)",
  "Sundanese",
  "Swahili",
  "Swedish",
  "Tajik",
  "Tamil",
  "Telugu",
  "Thai",
  "Turkish",
  "Ukrainian",
  "Urdu",
  "Uzbek",
  "Vietnamese",
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
  property raw : Bool
  property region : String?
  property related_videos : Bool
  property speed : Float32 | Float64
  property video_end : Float64 | Int32
  property video_loop : Bool
  property video_start : Float64 | Int32
  property volume : Int32
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

  def to_json(locale, json : JSON::Builder)
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
              json.field "index", "#{fmt["indexRange"]["start"]}-#{fmt["indexRange"]["end"]}"
              json.field "bitrate", fmt["bitrate"].as_i.to_s
              json.field "init", "#{fmt["initRange"]["start"]}-#{fmt["initRange"]["end"]}"
              json.field "url", fmt["url"]
              json.field "itag", fmt["itag"].as_i.to_s
              json.field "type", fmt["mimeType"]
              json.field "clen", fmt["contentLength"]
              json.field "lmt", fmt["lastModified"]
              json.field "projectionType", fmt["projectionType"]

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
              json.field "label", caption.name.simpleText
              json.field "languageCode", caption.languageCode
              json.field "url", "/api/v1/captions/#{id}?label=#{URI.encode_www_form(caption.name.simpleText)}"
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
                json.field "authorUrl", rv["author_url"]?
                json.field "authorId", rv["ucid"]?
                if rv["author_thumbnail"]?
                  json.field "authorThumbnails" do
                    json.array do
                      qualities = {32, 48, 76, 100, 176, 512}

                      qualities.each do |quality|
                        json.object do
                          json.field "url", rv["author_thumbnail"]?.try &.gsub(/s\d+-/, "s#{quality}-")
                          json.field "width", quality
                          json.field "height", quality
                        end
                      end
                    end
                  end
                end

                json.field "lengthSeconds", rv["length_seconds"]?.try &.to_i
                json.field "viewCountText", rv["short_view_count_text"]?
                json.field "viewCount", rv["view_count"]?.try &.empty? ? nil : rv["view_count"].to_i64
              end
            end
          end
        end
      end
    end
  end

  def to_json(locale, json : JSON::Builder | Nil = nil)
    if json
      to_json(locale, json)
    else
      JSON.build do |json|
        to_json(locale, json)
      end
    end
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
    info["microformat"]?.try &.["playerMicroformatRenderer"]?.try &.["lengthSeconds"]?.try &.as_s.to_i ||
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
    info["microformat"]?.try &.["playerMicroformatRenderer"]?.try &.["publishDate"]?.try { |t| Time.parse(t.as_s, "%Y-%m-%d", Time::Location.local) } || Time.local
  end

  def published=(other : Time)
    info["microformat"].as_h["playerMicroformatRenderer"].as_h["publishDate"] = JSON::Any.new(other.to_s("%Y-%m-%d"))
  end

  def cookie
    info["cookie"]?.try &.as_h.map { |k, v| "#{k}=#{v}" }.join("; ") || ""
  end

  def allow_ratings
    r = info["videoDetails"]["allowRatings"]?.try &.as_bool
    r.nil? ? false : r
  end

  def live_now
    info["videoDetails"]["isLiveContent"]?.try &.as_bool || false
  end

  def is_listed
    info["videoDetails"]["isCrawlable"]?.try &.as_bool || false
  end

  def is_upcoming
    info["videoDetails"]["isUpcoming"]?.try &.as_bool || false
  end

  def premiere_timestamp : Time?
    info["microformat"]?.try &.["playerMicroformatRenderer"]?
      .try &.["liveBroadcastDetails"]?.try &.["startTimestamp"]?.try { |t| Time.parse_rfc3339(t.as_s) }
  end

  def keywords
    info["videoDetails"]["keywords"]?.try &.as_a.map &.as_s || [] of String
  end

  def related_videos
    info["relatedVideos"]?.try &.as_a.map { |h| h.as_h.transform_values &.as_s } || [] of Hash(String, String)
  end

  def allowed_regions
    info["microformat"]?.try &.["playerMicroformatRenderer"]?
      .try &.["availableCountries"]?.try &.as_a.map &.as_s || [] of String
  end

  def author_thumbnail : String
    info["authorThumbnail"]?.try &.as_s || ""
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
        fmt["url"] = JSON::Any.new("#{fmt["url"]}#{decrypt_signature(fmt)}")
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
        fmt["url"] = JSON::Any.new("#{fmt["url"]}#{decrypt_signature(fmt)}")
      end

      fmt["url"] = JSON::Any.new("#{fmt["url"]}&host=#{URI.parse(fmt["url"].as_s).host}")
      fmt["url"] = JSON::Any.new("#{fmt["url"]}&region=#{self.info["region"]}") if self.info["region"]?
    end
    # See https://github.com/TeamNewPipe/NewPipe/issues/2415
    # Some streams are segmented by URL `sq/` rather than index, for now we just filter them out
    fmt_stream.reject! { |f| !f["indexRange"]? }
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
    storyboards = info["storyboards"]?
      .try &.as_h
        .try &.["playerStoryboardSpecRenderer"]?
          .try &.["spec"]?
            .try &.as_s.split("|")

    if !storyboards
      if storyboard = info["storyboards"]?
           .try &.as_h
             .try &.["playerLiveStoryboardSpecRenderer"]?
               .try &.["spec"]?
                 .try &.as_s
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

    storyboards.each_with_index do |storyboard, i|
      width, height, count, storyboard_width, storyboard_height, interval, _, sigh = storyboard.split("#")
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
    reason = info["playabilityStatus"]?.try &.["reason"]?
    paid = reason == "This video requires payment to watch." ? true : false
    paid
  end

  def premium
    keywords.includes? "YouTube Red"
  end

  def captions : Array(Caption)
    return @captions.as(Array(Caption)) if @captions
    captions = info["captions"]?.try &.["playerCaptionsTracklistRenderer"]?.try &.["captionTracks"]?.try &.as_a.map do |caption|
      caption = Caption.from_json(caption.to_json)
      caption.name.simpleText = caption.name.simpleText.split(" - ")[0]
      caption
    end
    captions ||= [] of Caption
    @captions = captions
    return @captions.as(Array(Caption))
  end

  def description
    description = info["microformat"]?.try &.["playerMicroformatRenderer"]?
      .try &.["description"]?.try &.["simpleText"]?.try &.as_s || ""
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
    info["streamingData"]?.try &.["hlsManifestUrl"]?.try &.as_s
  end

  def dash_manifest_url
    info["streamingData"]?.try &.["dashManifestUrl"]?.try &.as_s
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
    info["microformat"]?.try &.["playerMicroformatRenderer"]["isFamilySafe"]?.try &.as_bool || false
  end

  def wilson_score : Float64
    ci_lower_bound(likes, likes + dislikes).round(4)
  end

  def engagement : Float64
    ((likes + dislikes) / views).round(4)
  end

  def reason : String?
    info["reason"]?.try &.as_s
  end

  def session_token : String?
    info["sessionToken"]?.try &.as_s?
  end
end

struct CaptionName
  include JSON::Serializable

  property simpleText : String
end

struct Caption
  include JSON::Serializable

  property name : CaptionName
  property baseUrl : String
  property languageCode : String
end

class VideoRedirect < Exception
  property video_id : String

  def initialize(@video_id)
  end
end

def parse_related(r : JSON::Any) : JSON::Any?
  # TODO: r["endScreenPlaylistRenderer"], etc.
  return if !r["endScreenVideoRenderer"]?
  r = r["endScreenVideoRenderer"].as_h

  return if !r["lengthInSeconds"]?

  rv = {} of String => JSON::Any
  rv["author"] = r["shortBylineText"]["runs"][0]?.try &.["text"] || JSON::Any.new("")
  rv["ucid"] = r["shortBylineText"]["runs"][0]?.try &.["navigationEndpoint"]["browseEndpoint"]["browseId"] || JSON::Any.new("")
  rv["author_url"] = JSON::Any.new("/channel/#{rv["ucid"]}")
  rv["length_seconds"] = JSON::Any.new(r["lengthInSeconds"].as_i.to_s)
  rv["title"] = r["title"]["simpleText"]
  rv["short_view_count_text"] = JSON::Any.new(r["shortViewCountText"]?.try &.["simpleText"]?.try &.as_s || "")
  rv["view_count"] = JSON::Any.new(r["title"]["accessibility"]?.try &.["accessibilityData"]["label"].as_s.match(/(?<views>[1-9](\d+,?)*) views/).try &.["views"].gsub(/\D/, "") || "")
  rv["id"] = r["videoId"]
  JSON::Any.new(rv)
end

def extract_polymer_config(body)
  params = {} of String => JSON::Any
  player_response = body.match(/window\["ytInitialPlayerResponse"\]\s*=\s*(?<info>.*?);\n/)
    .try { |r| JSON.parse(r["info"]).as_h }

  if body.includes?("To continue with your YouTube experience, please fill out the form below.") ||
     body.includes?("https://www.google.com/sorry/index")
    params["reason"] = JSON::Any.new("Could not extract video info. Instance is likely blocked.")
  elsif !player_response
    params["reason"] = JSON::Any.new("Video unavailable.")
  elsif player_response["playabilityStatus"]?.try &.["status"]?.try &.as_s != "OK"
    reason = player_response["playabilityStatus"]["errorScreen"]?.try &.["playerErrorMessageRenderer"]?.try &.["subreason"]?.try { |s| s["simpleText"]?.try &.as_s || s["runs"].as_a.map { |r| r["text"] }.join("") } ||
             player_response["playabilityStatus"]["reason"].as_s
    params["reason"] = JSON::Any.new(reason)
  end

  params["sessionToken"] = JSON::Any.new(body.match(/"XSRF_TOKEN":"(?<session_token>[^"]+)"/).try &.["session_token"]?)
  params["shortDescription"] = JSON::Any.new(body.match(/"og:description" content="(?<description>[^"]+)"/).try &.["description"]?)

  return params if !player_response

  {"captions", "microformat", "playabilityStatus", "storyboards", "videoDetails"}.each do |f|
    params[f] = player_response[f] if player_response[f]?
  end

  yt_initial_data = body.match(/(window\["ytInitialData"\]|var\s+ytInitialData)\s*=\s*(?<info>.*?);\s*\n/)
    .try { |r| JSON.parse(r["info"]).as_h }

  params["relatedVideos"] = yt_initial_data.try &.["playerOverlays"]?.try &.["playerOverlayRenderer"]?
    .try &.["endScreen"]?.try &.["watchNextEndScreenRenderer"]?.try &.["results"]?.try &.as_a.compact_map { |r|
      parse_related r
    }.try { |a| JSON::Any.new(a) } || yt_initial_data.try &.["webWatchNextResponseExtensionData"]?.try &.["relatedVideoArgs"]?
    .try &.as_s.split(",").map { |r|
      r = HTTP::Params.parse(r).to_h
      JSON::Any.new(Hash.zip(r.keys, r.values.map { |v| JSON::Any.new(v) }))
    }.try { |a| JSON::Any.new(a) } || JSON::Any.new([] of JSON::Any)

  primary_results = yt_initial_data.try &.["contents"]?.try &.["twoColumnWatchNextResults"]?.try &.["results"]?
    .try &.["results"]?.try &.["contents"]?
  sentiment_bar = primary_results.try &.as_a.select { |object| object["videoPrimaryInfoRenderer"]? }[0]?
    .try &.["videoPrimaryInfoRenderer"]?
      .try &.["sentimentBar"]?
        .try &.["sentimentBarRenderer"]?
          .try &.["tooltip"]?
            .try &.as_s

  likes, dislikes = sentiment_bar.try &.split(" / ", 2).map &.gsub(/\D/, "").to_i64 || {0_i64, 0_i64}
  params["likes"] = JSON::Any.new(likes)
  params["dislikes"] = JSON::Any.new(dislikes)

  params["descriptionHtml"] = JSON::Any.new(primary_results.try &.as_a.select { |object| object["videoSecondaryInfoRenderer"]? }[0]?
    .try &.["videoSecondaryInfoRenderer"]?.try &.["description"]?.try &.["runs"]?
      .try &.as_a.try { |t| content_to_comment_html(t).gsub("\n", "<br/>") } || "<p></p>")

  metadata = primary_results.try &.as_a.select { |object| object["videoSecondaryInfoRenderer"]? }[0]?
    .try &.["videoSecondaryInfoRenderer"]?
      .try &.["metadataRowContainer"]?
        .try &.["metadataRowContainerRenderer"]?
          .try &.["rows"]?
            .try &.as_a

  params["genre"] = params["microformat"]?.try &.["playerMicroformatRenderer"]?.try &.["category"]? || JSON::Any.new("")
  params["genreUrl"] = JSON::Any.new(nil)

  metadata.try &.each do |row|
    title = row["metadataRowRenderer"]?.try &.["title"]?.try &.["simpleText"]?.try &.as_s
    contents = row["metadataRowRenderer"]?
      .try &.["contents"]?
        .try &.as_a[0]?

    if title.try &.== "Category"
      contents = contents.try &.["runs"]?
        .try &.as_a[0]?

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

  author_info = primary_results.try &.as_a.select { |object| object["videoSecondaryInfoRenderer"]? }[0]?
    .try &.["videoSecondaryInfoRenderer"]?.try &.["owner"]?.try &.["videoOwnerRenderer"]?

  params["authorThumbnail"] = JSON::Any.new(author_info.try &.["thumbnail"]?
    .try &.["thumbnails"]?.try &.as_a[0]?.try &.["url"]?
      .try &.as_s || "")

  params["subCountText"] = JSON::Any.new(author_info.try &.["subscriberCountText"]?
    .try { |t| t["simpleText"]? || t["runs"]?.try &.[0]?.try &.["text"]? }.try &.as_s.split(" ", 2)[0] || "-")

  initial_data = body.match(/ytplayer\.config\s*=\s*(?<info>.*?);ytplayer\.web_player_context_config/)
    .try { |r| JSON.parse(r["info"]) }.try &.["args"]["player_response"]?
    .try &.as_s?.try &.try { |r| JSON.parse(r).as_h }

  return params if !initial_data

  {"playabilityStatus", "streamingData"}.each do |f|
    params[f] = initial_data[f] if initial_data[f]?
  end

  params
end

def get_video(id, db, refresh = true, region = nil, force_refresh = false)
  if (video = db.query_one?("SELECT * FROM videos WHERE id = $1", id, as: Video)) && !region
    # If record was last updated over 10 minutes ago, or video has since premiered,
    # refresh (expire param in response lasts for 6 hours)
    if (refresh &&
       (Time.utc - video.updated > 10.minutes) ||
       (video.premiere_timestamp.try &.< Time.utc)) ||
       force_refresh
      begin
        video = fetch_video(id, region)
        db.exec("UPDATE videos SET (id, info, updated) = ($1, $2, $3) WHERE id = $1", video.id, video.info.to_json, video.updated)
      rescue ex
        db.exec("DELETE FROM videos * WHERE id = $1", id)
        raise ex
      end
    end
  else
    video = fetch_video(id, region)
    if !region
      db.exec("INSERT INTO videos VALUES ($1, $2, $3) ON CONFLICT (id) DO NOTHING", video.id, video.info.to_json, video.updated)
    end
  end

  return video
end

def fetch_video(id, region)
  response = YT_POOL.client(region, &.get("/watch?v=#{id}&gl=US&hl=en&has_verified=1&bpctr=9999999999"))

  if md = response.headers["location"]?.try &.match(/v=(?<id>[a-zA-Z0-9_-]{11})/)
    raise VideoRedirect.new(video_id: md["id"])
  end

  info = extract_polymer_config(response.body)
  info["cookie"] = JSON::Any.new(response.cookies.to_h.transform_values { |v| JSON::Any.new(v.value) })
  allowed_regions = info["microformat"]?.try &.["playerMicroformatRenderer"]["availableCountries"]?.try &.as_a.map &.as_s || [] of String

  # Check for region-blocks
  if info["reason"]?.try &.as_s.includes?("your country")
    bypass_regions = PROXY_LIST.keys & allowed_regions
    if !bypass_regions.empty?
      region = bypass_regions[rand(bypass_regions.size)]
      response = YT_POOL.client(region, &.get("/watch?v=#{id}&gl=US&hl=en&has_verified=1&bpctr=9999999999"))

      region_info = extract_polymer_config(response.body)
      region_info["region"] = JSON::Any.new(region) if region
      region_info["cookie"] = JSON::Any.new(response.cookies.to_h.transform_values { |v| JSON::Any.new(v.value) })
      info = region_info if !region_info["reason"]?
    end
  end

  # Try to pull streams from embed URL
  if info["reason"]?
    embed_page = YT_POOL.client &.get("/embed/#{id}").body
    sts = embed_page.match(/"sts"\s*:\s*(?<sts>\d+)/).try &.["sts"]? || ""
    embed_info = HTTP::Params.parse(YT_POOL.client &.get("/get_video_info?html5=1&video_id=#{id}&eurl=https://youtube.googleapis.com/v/#{id}&gl=US&hl=en&sts=#{sts}").body)

    if embed_info["player_response"]?
      player_response = JSON.parse(embed_info["player_response"])
      {"captions", "microformat", "playabilityStatus", "streamingData", "videoDetails", "storyboards"}.each do |f|
        info[f] = player_response[f] if player_response[f]?
      end
    end

    initial_data = JSON.parse(embed_info["watch_next_response"]) if embed_info["watch_next_response"]?

    info["relatedVideos"] = initial_data.try &.["playerOverlays"]?.try &.["playerOverlayRenderer"]?
      .try &.["endScreen"]?.try &.["watchNextEndScreenRenderer"]?.try &.["results"]?.try &.as_a.compact_map { |r|
        parse_related r
      }.try { |a| JSON::Any.new(a) } || embed_info["rvs"]?.try &.split(",").map { |r|
      r = HTTP::Params.parse(r).to_h
      JSON::Any.new(Hash.zip(r.keys, r.values.map { |v| JSON::Any.new(v) }))
    }.try { |a| JSON::Any.new(a) } || JSON::Any.new([] of JSON::Any)
  end

  raise info["reason"]?.try &.as_s || "" if !info["videoDetails"]?

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

def process_continuation(db, query, plid, id)
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
  comments = query["comments"]?.try &.split(",").map { |a| a.downcase }
  continue = query["continue"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  continue_autoplay = query["continue_autoplay"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  listen = query["listen"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  local = query["local"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  player_style = query["player_style"]?
  preferred_captions = query["subtitles"]?.try &.split(",").map { |a| a.downcase }
  quality = query["quality"]?
  region = query["region"]?
  related_videos = query["related_videos"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  speed = query["speed"]?.try &.rchop("x").to_f?
  video_loop = query["loop"]?.try { |q| (q == "true" || q == "1").to_unsafe }
  volume = query["volume"]?.try &.to_i?

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
    related_videos ||= preferences.related_videos.to_unsafe
    speed ||= preferences.speed
    video_loop ||= preferences.video_loop.to_unsafe
    volume ||= preferences.volume
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
  related_videos ||= CONFIG.default_user_preferences.related_videos.to_unsafe
  speed ||= CONFIG.default_user_preferences.speed
  video_loop ||= CONFIG.default_user_preferences.video_loop.to_unsafe
  volume ||= CONFIG.default_user_preferences.volume

  annotations = annotations == 1
  autoplay = autoplay == 1
  continue = continue == 1
  continue_autoplay = continue_autoplay == 1
  listen = listen == 1
  local = local == 1
  related_videos = related_videos == 1
  video_loop = video_loop == 1

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
    raw:                raw,
    region:             region,
    related_videos:     related_videos,
    speed:              speed,
    video_end:          video_end,
    video_loop:         video_loop,
    video_start:        video_start,
    volume:             volume,
  })

  return params
end

def build_thumbnails(id)
  return {
    {name: "maxres", host: "#{HOST_URL}", url: "maxres", height: 720, width: 1280},
    {name: "maxresdefault", host: "https://i.ytimg.com", url: "maxresdefault", height: 720, width: 1280},
    {name: "sddefault", host: "https://i.ytimg.com", url: "sddefault", height: 480, width: 640},
    {name: "high", host: "https://i.ytimg.com", url: "hqdefault", height: 360, width: 480},
    {name: "medium", host: "https://i.ytimg.com", url: "mqdefault", height: 180, width: 320},
    {name: "default", host: "https://i.ytimg.com", url: "default", height: 90, width: 120},
    {name: "start", host: "https://i.ytimg.com", url: "1", height: 90, width: 120},
    {name: "middle", host: "https://i.ytimg.com", url: "2", height: 90, width: 120},
    {name: "end", host: "https://i.ytimg.com", url: "3", height: 90, width: 120},
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
