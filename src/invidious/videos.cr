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

REGIONS        = {"AD", "AE", "AF", "AG", "AI", "AL", "AM", "AO", "AQ", "AR", "AS", "AT", "AU", "AW", "AX", "AZ", "BA", "BB", "BD", "BE", "BF", "BG", "BH", "BI", "BJ", "BL", "BM", "BN", "BO", "BQ", "BR", "BS", "BT", "BV", "BW", "BY", "BZ", "CA", "CC", "CD", "CF", "CG", "CH", "CI", "CK", "CL", "CM", "CN", "CO", "CR", "CU", "CV", "CW", "CX", "CY", "CZ", "DE", "DJ", "DK", "DM", "DO", "DZ", "EC", "EE", "EG", "EH", "ER", "ES", "ET", "FI", "FJ", "FK", "FM", "FO", "FR", "GA", "GB", "GD", "GE", "GF", "GG", "GH", "GI", "GL", "GM", "GN", "GP", "GQ", "GR", "GS", "GT", "GU", "GW", "GY", "HK", "HM", "HN", "HR", "HT", "HU", "ID", "IE", "IL", "IM", "IN", "IO", "IQ", "IR", "IS", "IT", "JE", "JM", "JO", "JP", "KE", "KG", "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ", "LA", "LB", "LC", "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY", "MA", "MC", "MD", "ME", "MF", "MG", "MH", "MK", "ML", "MM", "MN", "MO", "MP", "MQ", "MR", "MS", "MT", "MU", "MV", "MW", "MX", "MY", "MZ", "NA", "NC", "NE", "NF", "NG", "NI", "NL", "NO", "NP", "NR", "NU", "NZ", "OM", "PA", "PE", "PF", "PG", "PH", "PK", "PL", "PM", "PN", "PR", "PS", "PT", "PW", "PY", "QA", "RE", "RO", "RS", "RU", "RW", "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SR", "SS", "ST", "SV", "SX", "SY", "SZ", "TC", "TD", "TF", "TG", "TH", "TJ", "TK", "TL", "TM", "TN", "TO", "TR", "TT", "TV", "TW", "TZ", "UA", "UG", "UM", "US", "UY", "UZ", "VA", "VC", "VE", "VG", "VI", "VN", "VU", "WF", "WS", "YE", "YT", "ZA", "ZM", "ZW"}
BYPASS_REGIONS = {
  "GB",
  "DE",
  "FR",
  "IN",
  "CN",
  "RU",
  "CA",
  "JP",
  "IT",
  "TH",
  "ES",
  "AE",
  "KR",
  "IR",
  "BR",
  "PK",
  "ID",
  "BD",
  "MX",
  "PH",
  "EG",
  "VN",
  "CD",
  "TR",
}

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
  "138" => {"ext" => "mp4", "format" => "DASH video", "vcodec" => "h264"}, # Height can vary (https=>//github.com/rg3/youtube-dl/issues/4559)
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
}

struct VideoPreferences
  json_mapping({
    annotations:        Bool,
    autoplay:           Bool,
    continue:           Bool,
    continue_autoplay:  Bool,
    controls:           Bool,
    listen:             Bool,
    local:              Bool,
    preferred_captions: Array(String),
    quality:            String,
    raw:                Bool,
    region:             String?,
    related_videos:     Bool,
    speed:              (Float32 | Float64),
    video_end:          (Float64 | Int32),
    video_loop:         Bool,
    video_start:        (Float64 | Int32),
    volume:             Int32,
  })
end

struct Video
  property player_json : JSON::Any?

  module HTTPParamConverter
    def self.from_rs(rs)
      HTTP::Params.parse(rs.read(String))
    end
  end

  def to_json(locale, config, kemal_config, decrypt_function)
    JSON.build do |json|
      json.object do
        json.field "title", self.title
        json.field "videoId", self.id
        json.field "videoThumbnails" do
          generate_thumbnails(json, self.id, config, kemal_config)
        end
        json.field "storyboards" do
          generate_storyboards(json, self.id, self.storyboards, config, kemal_config)
        end

        description_html, description = html_to_content(self.description)

        json.field "description", description
        json.field "descriptionHtml", description_html
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
                json.field "url", self.author_thumbnail.gsub("=s48-", "=s#{quality}-")
                json.field "width", quality
                json.field "height", quality
              end
            end
          end
        end

        json.field "subCountText", self.sub_count_text

        json.field "lengthSeconds", self.info["length_seconds"].to_i
        json.field "allowRatings", self.allow_ratings
        json.field "rating", self.info["avg_rating"].to_f32
        json.field "isListed", self.is_listed
        json.field "liveNow", self.live_now
        json.field "isUpcoming", self.is_upcoming

        if self.premiere_timestamp
          json.field "premiereTimestamp", self.premiere_timestamp.not_nil!.to_unix
        end

        if self.player_response["streamingData"]?.try &.["hlsManifestUrl"]?
          host_url = make_host_url(config, kemal_config)

          hlsvp = self.player_response["streamingData"]["hlsManifestUrl"].as_s
          hlsvp = hlsvp.gsub("https://manifest.googlevideo.com", host_url)

          json.field "hlsUrl", hlsvp
        end

        json.field "dashUrl", "#{make_host_url(config, kemal_config)}/api/manifest/dash/id/#{id}"

        json.field "adaptiveFormats" do
          json.array do
            self.adaptive_fmts(decrypt_function).each do |fmt|
              json.object do
                json.field "index", fmt["index"]
                json.field "bitrate", fmt["bitrate"]
                json.field "init", fmt["init"]
                json.field "url", fmt["url"]
                json.field "itag", fmt["itag"]
                json.field "type", fmt["type"]
                json.field "clen", fmt["clen"]
                json.field "lmt", fmt["lmt"]
                json.field "projectionType", fmt["projection_type"]

                fmt_info = itag_to_metadata?(fmt["itag"])
                if fmt_info
                  fps = fmt_info["fps"]?.try &.to_i || fmt["fps"]?.try &.to_i || 30
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
            self.fmt_stream(decrypt_function).each do |fmt|
              json.object do
                json.field "url", fmt["url"]
                json.field "itag", fmt["itag"]
                json.field "type", fmt["type"]
                json.field "quality", fmt["quality"]

                fmt_info = itag_to_metadata?(fmt["itag"])
                if fmt_info
                  fps = fmt_info["fps"]?.try &.to_i || fmt["fps"]?.try &.to_i || 30
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
                json.field "url", "/api/v1/captions/#{id}?label=#{URI.escape(caption.name.simpleText)}"
              end
            end
          end
        end

        json.field "recommendedVideos" do
          json.array do
            self.info["rvs"]?.try &.split(",").each do |rv|
              rv = HTTP::Params.parse(rv)

              if rv["id"]?
                json.object do
                  json.field "videoId", rv["id"]
                  json.field "title", rv["title"]
                  json.field "videoThumbnails" do
                    generate_thumbnails(json, rv["id"], config, kemal_config)
                  end
                  json.field "author", rv["author"]
                  json.field "lengthSeconds", rv["length_seconds"].to_i
                  json.field "viewCountText", rv["short_view_count_text"]
                end
              end
            end
          end
        end
      end
    end
  end

  def allow_ratings
    allow_ratings = player_response["videoDetails"]?.try &.["allowRatings"]?.try &.as_bool

    if allow_ratings.nil?
      return true
    end

    return allow_ratings
  end

  def live_now
    live_now = self.player_response["videoDetails"]?.try &.["isLive"]?.try &.as_bool

    if live_now.nil?
      return false
    end

    return live_now
  end

  def is_listed
    is_listed = player_response["videoDetails"]?.try &.["isCrawlable"]?.try &.as_bool

    if is_listed.nil?
      return true
    end

    return is_listed
  end

  def is_upcoming
    is_upcoming = player_response["videoDetails"]?.try &.["isUpcoming"]?.try &.as_bool

    if is_upcoming.nil?
      return false
    end

    return is_upcoming
  end

  def premiere_timestamp
    if self.is_upcoming
      premiere_timestamp = player_response["playabilityStatus"]?
        .try &.["liveStreamability"]?
          .try &.["liveStreamabilityRenderer"]?
            .try &.["offlineSlate"]?
              .try &.["liveStreamOfflineSlateRenderer"]?
                .try &.["scheduledStartTime"]?.try &.as_s.to_i64
    end

    if premiere_timestamp
      premiere_timestamp = Time.unix(premiere_timestamp)
    end

    return premiere_timestamp
  end

  def keywords
    keywords = self.player_response["videoDetails"]?.try &.["keywords"]?.try &.as_a
    keywords ||= [] of String

    return keywords
  end

  def fmt_stream(decrypt_function)
    streams = [] of HTTP::Params

    if fmt_streams = self.player_response["streamingData"]?.try &.["formats"]?
      fmt_streams.as_a.each do |fmt_stream|
        if !fmt_stream.as_h?
          next
        end

        fmt = {} of String => String

        fmt["lmt"] = fmt_stream["lastModified"]?.try &.as_s || "0"
        fmt["projection_type"] = "1"
        fmt["type"] = fmt_stream["mimeType"].as_s
        fmt["clen"] = fmt_stream["contentLength"]?.try &.as_s || "0"
        fmt["bitrate"] = fmt_stream["bitrate"]?.try &.as_i.to_s || "0"
        fmt["itag"] = fmt_stream["itag"].as_i.to_s
        fmt["url"] = fmt_stream["url"].as_s
        fmt["quality"] = fmt_stream["quality"].as_s

        if fmt_stream["width"]?
          fmt["size"] = "#{fmt_stream["width"]}x#{fmt_stream["height"]}"
          fmt["height"] = fmt_stream["height"].as_i.to_s
        end

        if fmt_stream["fps"]?
          fmt["fps"] = fmt_stream["fps"].as_i.to_s
        end

        if fmt_stream["qualityLabel"]?
          fmt["quality_label"] = fmt_stream["qualityLabel"].as_s
        end

        params = HTTP::Params.new
        fmt.each do |key, value|
          params[key] = value
        end

        streams << params
      end

      streams.sort_by! { |stream| stream["height"].to_i }.reverse!
    elsif fmt_stream = self.info["url_encoded_fmt_stream_map"]?
      fmt_stream.split(",").each do |string|
        if !string.empty?
          streams << HTTP::Params.parse(string)
        end
      end
    end

    streams.each { |s| s.add("label", "#{s["quality"]} - #{s["type"].split(";")[0].split("/")[1]}") }
    streams = streams.uniq { |s| s["label"] }

    if self.info["region"]?
      streams.each do |fmt|
        fmt["url"] += "&region=" + self.info["region"]
      end
    end

    streams.each do |fmt|
      fmt["url"] += "&host=" + (URI.parse(fmt["url"]).host || "")
      fmt["url"] += decrypt_signature(fmt, decrypt_function)
    end

    return streams
  end

  def adaptive_fmts(decrypt_function)
    adaptive_fmts = [] of HTTP::Params

    if fmts = self.player_response["streamingData"]?.try &.["adaptiveFormats"]?
      fmts.as_a.each do |adaptive_fmt|
        if !adaptive_fmt.as_h?
          next
        end

        fmt = {} of String => String

        if init = adaptive_fmt["initRange"]?
          fmt["init"] = "#{init["start"]}-#{init["end"]}"
        end
        fmt["init"] ||= "0-0"

        fmt["lmt"] = adaptive_fmt["lastModified"]?.try &.as_s || "0"
        fmt["projection_type"] = "1"
        fmt["type"] = adaptive_fmt["mimeType"].as_s
        fmt["clen"] = adaptive_fmt["contentLength"]?.try &.as_s || "0"
        fmt["bitrate"] = adaptive_fmt["bitrate"]?.try &.as_i.to_s || "0"
        fmt["itag"] = adaptive_fmt["itag"].as_i.to_s
        fmt["url"] = adaptive_fmt["url"].as_s

        if index = adaptive_fmt["indexRange"]?
          fmt["index"] = "#{index["start"]}-#{index["end"]}"
        end
        fmt["index"] ||= "0-0"

        if adaptive_fmt["width"]?
          fmt["size"] = "#{adaptive_fmt["width"]}x#{adaptive_fmt["height"]}"
        end

        if adaptive_fmt["fps"]?
          fmt["fps"] = adaptive_fmt["fps"].as_i.to_s
        end

        if adaptive_fmt["qualityLabel"]?
          fmt["quality_label"] = adaptive_fmt["qualityLabel"].as_s
        end

        params = HTTP::Params.new
        fmt.each do |key, value|
          params[key] = value
        end

        adaptive_fmts << params
      end
    elsif fmts = self.info["adaptive_fmts"]?
      fmts.split(",") do |string|
        adaptive_fmts << HTTP::Params.parse(string)
      end
    end

    if self.info["region"]?
      adaptive_fmts.each do |fmt|
        fmt["url"] += "&region=" + self.info["region"]
      end
    end

    adaptive_fmts.each do |fmt|
      fmt["url"] += "&host=" + (URI.parse(fmt["url"]).host || "")
      fmt["url"] += decrypt_signature(fmt, decrypt_function)
    end

    return adaptive_fmts
  end

  def video_streams(adaptive_fmts)
    video_streams = adaptive_fmts.select { |s| s["type"].starts_with? "video" }

    return video_streams
  end

  def audio_streams(adaptive_fmts)
    audio_streams = adaptive_fmts.select { |s| s["type"].starts_with? "audio" }
    audio_streams.sort_by! { |s| s["bitrate"].to_i }.reverse!
    audio_streams.each do |stream|
      stream["bitrate"] = (stream["bitrate"].to_f64/1000).to_i.to_s
    end

    return audio_streams
  end

  def player_response
    if !@player_json
      @player_json = JSON.parse(@info["player_response"])
    end

    return @player_json.not_nil!
  end

  def storyboards
    storyboards = self.player_response["storyboards"]?
      .try &.as_h
        .try &.["playerStoryboardSpecRenderer"]?

    if !storyboards
      storyboards = self.player_response["storyboards"]?
        .try &.as_h
          .try &.["playerLiveStoryboardSpecRenderer"]?

      if storyboard = storyboards.try &.["spec"]?
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

    storyboards = storyboards.try &.["spec"]?
      .try &.as_s.split("|")

    items = [] of NamedTuple(
      url: String,
      width: Int32,
      height: Int32,
      count: Int32,
      interval: Int32,
      storyboard_width: Int32,
      storyboard_height: Int32,
      storyboard_count: Int32)

    if !storyboards
      return items
    end

    url = storyboards.shift

    storyboards.each_with_index do |storyboard, i|
      width, height, count, storyboard_width, storyboard_height, interval, _, sigh = storyboard.split("#")

      width = width.to_i
      height = height.to_i
      count = count.to_i
      interval = interval.to_i
      storyboard_width = storyboard_width.to_i
      storyboard_height = storyboard_height.to_i

      items << {
        url:               "#{url}&sigh=#{sigh}".sub("$L", i).sub("$N", "M$M"),
        width:             width,
        height:            height,
        count:             count,
        interval:          interval,
        storyboard_width:  storyboard_width,
        storyboard_height: storyboard_height,
        storyboard_count:  (count.to_f / (storyboard_width.to_f * storyboard_height.to_f)).ceil.to_i,
      }
    end

    items
  end

  def paid
    reason = self.player_response["playabilityStatus"]?.try &.["reason"]?

    if reason == "This video requires payment to watch."
      paid = true
    else
      paid = false
    end

    return paid
  end

  def premium
    premium = self.player_response.to_s.includes? "Get YouTube without the ads."
    return premium
  end

  def captions
    captions = [] of Caption
    if player_response["captions"]?
      caption_list = player_response["captions"]["playerCaptionsTracklistRenderer"]["captionTracks"]?.try &.as_a
      caption_list ||= [] of JSON::Any

      caption_list.each do |caption|
        caption = Caption.from_json(caption.to_json)
        caption.name.simpleText = caption.name.simpleText.split(" - ")[0]
        captions << caption
      end
    end

    return captions
  end

  def short_description
    description = self.description.gsub("<br>", " ")
    description = description.gsub("<br/>", " ")
    description = XML.parse_html(description).content[0..200].gsub('"', "&quot;").gsub("\n", " ").strip(" ")
    if description.empty?
      description = " "
    end

    return description
  end

  def length_seconds
    return self.info["length_seconds"].to_i
  end

  db_mapping({
    id:   String,
    info: {
      type:      HTTP::Params,
      default:   HTTP::Params.parse(""),
      converter: Video::HTTPParamConverter,
    },
    updated:            Time,
    title:              String,
    views:              Int64,
    likes:              Int32,
    dislikes:           Int32,
    wilson_score:       Float64,
    published:          Time,
    description:        String,
    language:           String?,
    author:             String,
    ucid:               String,
    allowed_regions:    Array(String),
    is_family_friendly: Bool,
    genre:              String,
    genre_url:          String,
    license:            String,
    sub_count_text:     String,
    author_thumbnail:   String,
  })
end

struct Caption
  JSON.mapping(
    name: CaptionName,
    baseUrl: String,
    languageCode: String
  )
end

struct CaptionName
  JSON.mapping(
    simpleText: String,
  )
end

class VideoRedirect < Exception
end

def get_video(id, db, proxies = {} of String => Array({ip: String, port: Int32}), refresh = true, region = nil, force_refresh = false)
  if db.query_one?("SELECT EXISTS (SELECT true FROM videos WHERE id = $1)", id, as: Bool) && !region
    video = db.query_one("SELECT * FROM videos WHERE id = $1", id, as: Video)

    # If record was last updated over 10 minutes ago, refresh (expire param in response lasts for 6 hours)
    if (refresh && Time.now - video.updated > 10.minutes) || force_refresh
      begin
        video = fetch_video(id, proxies, region)
        video_array = video.to_a

        args = arg_array(video_array[1..-1], 2)

        db.exec("UPDATE videos SET (info,updated,title,views,likes,dislikes,wilson_score,\
          published,description,language,author,ucid,allowed_regions,is_family_friendly,\
          genre,genre_url,license,sub_count_text,author_thumbnail)\
          = (#{args}) WHERE id = $1", video_array)
      rescue ex
        db.exec("DELETE FROM videos * WHERE id = $1", id)
        raise ex
      end
    end
  else
    video = fetch_video(id, proxies, region)
    video_array = video.to_a

    args = arg_array(video_array)

    if !region
      db.exec("INSERT INTO videos VALUES (#{args}) ON CONFLICT (id) DO NOTHING", video_array)
    end
  end

  return video
end

def extract_polymer_config(body, html)
  params = HTTP::Params.new

  params["session_token"] = body.match(/"XSRF_TOKEN":"(?<session_token>[A-Za-z0-9\_\-\=]+)"/).try &.["session_token"] || ""

  html_info = JSON.parse(body.match(/ytplayer\.config = (?<info>.*?);ytplayer\.load/).try &.["info"] || "{}").try &.["args"]?.try &.as_h

  if html_info
    html_info.each do |key, value|
      params[key] = value.to_s
    end
  end

  initial_data = JSON.parse(body.match(/window\["ytInitialData"\] = (?<info>.*?);\n/).try &.["info"] || "{}")

  primary_results = initial_data["contents"]?
    .try &.["twoColumnWatchNextResults"]?
      .try &.["results"]?
        .try &.["results"]?
          .try &.["contents"]?

  comment_continuation = primary_results.try &.as_a.select { |object| object["itemSectionRenderer"]? }[0]?
    .try &.["itemSectionRenderer"]?
      .try &.["continuations"]?
        .try &.[0]?
          .try &.["nextContinuationData"]?

  params["ctoken"] = comment_continuation.try &.["continuation"]?.try &.as_s || ""
  params["itct"] = comment_continuation.try &.["clickTrackingParams"]?.try &.as_s || ""

  recommended_videos = initial_data["contents"]?
    .try &.["twoColumnWatchNextResults"]?
      .try &.["secondaryResults"]?
        .try &.["secondaryResults"]?
          .try &.["results"]?
            .try &.as_a

  rvs = [] of String

  recommended_videos.try &.each do |compact_renderer|
    if compact_renderer["compactRadioRenderer"]? || compact_renderer["compactPlaylistRenderer"]?
      # TODO
    elsif compact_renderer["compactVideoRenderer"]?
      compact_renderer = compact_renderer["compactVideoRenderer"]

      recommended_video = HTTP::Params.new
      recommended_video["id"] = compact_renderer["videoId"].as_s
      recommended_video["title"] = compact_renderer["title"]["simpleText"].as_s
      recommended_video["author"] = compact_renderer["shortBylineText"]["runs"].as_a[0]["text"].as_s
      recommended_video["ucid"] = compact_renderer["shortBylineText"]["runs"].as_a[0]["navigationEndpoint"]["browseEndpoint"]["browseId"].as_s
      recommended_video["author_thumbnail"] = compact_renderer["channelThumbnail"]["thumbnails"][0]["url"].as_s

      recommended_video["short_view_count_text"] = compact_renderer["shortViewCountText"]["simpleText"].as_s
      recommended_video["view_count"] = compact_renderer["viewCountText"]?.try &.["simpleText"]?.try &.as_s.delete(", views").to_i64?.try &.to_s || "0"
      recommended_video["length_seconds"] = decode_length_seconds(compact_renderer["lengthText"]?.try &.["simpleText"]?.try &.as_s || "0:00").to_s

      rvs << recommended_video.to_s
    end
  end
  params["rvs"] = rvs.join(",")

  # TODO: Watching now
  params["views"] = primary_results.try &.as_a.select { |object| object["videoPrimaryInfoRenderer"]? }[0]?
    .try &.["videoPrimaryInfoRenderer"]?
      .try &.["viewCount"]?
        .try &.["videoViewCountRenderer"]?
          .try &.["viewCount"]?
            .try &.["simpleText"]?
              .try &.as_s.gsub(/\D/, "").to_i64.to_s || "0"

  sentiment_bar = primary_results.try &.as_a.select { |object| object["videoPrimaryInfoRenderer"]? }[0]?
    .try &.["videoPrimaryInfoRenderer"]?
      .try &.["sentimentBar"]?
        .try &.["sentimentBarRenderer"]?
          .try &.["tooltip"]?
            .try &.as_s

  likes, dislikes = sentiment_bar.try &.split(" / ").map { |a| a.delete(", ").to_i32 }[0, 2] || {0, 0}

  params["likes"] = "#{likes}"
  params["dislikes"] = "#{dislikes}"

  published = primary_results.try &.as_a.select { |object| object["videoSecondaryInfoRenderer"]? }[0]?
    .try &.["videoSecondaryInfoRenderer"]?
      .try &.["dateText"]?
        .try &.["simpleText"]?
          .try &.as_s.split(" ")[-3..-1].join(" ")

  if published
    params["published"] = Time.parse(published, "%b %-d, %Y", Time::Location.local).to_unix.to_s
  else
    params["published"] = Time.new(1990, 1, 1).to_unix.to_s
  end

  params["description_html"] = "<p></p>"

  description_html = primary_results.try &.as_a.select { |object| object["videoSecondaryInfoRenderer"]? }[0]?
    .try &.["videoSecondaryInfoRenderer"]?
      .try &.["description"]?
        .try &.["runs"]?
          .try &.as_a

  if description_html
    params["description_html"] = content_to_comment_html(description_html)
  end

  metadata = primary_results.try &.as_a.select { |object| object["videoSecondaryInfoRenderer"]? }[0]?
    .try &.["videoSecondaryInfoRenderer"]?
      .try &.["metadataRowContainer"]?
        .try &.["metadataRowContainerRenderer"]?
          .try &.["rows"]?
            .try &.as_a

  params["genre"] = ""
  params["genre_ucid"] = ""
  params["license"] = ""

  metadata.try &.each do |row|
    title = row["metadataRowRenderer"]?.try &.["title"]?.try &.["simpleText"]?.try &.as_s
    contents = row["metadataRowRenderer"]?
      .try &.["contents"]?
        .try &.as_a[0]?

    if title.try &.== "Category"
      contents = contents.try &.["runs"]?
        .try &.as_a[0]?

      params["genre"] = contents.try &.["text"]?
        .try &.as_s || ""
      params["genre_ucid"] = contents.try &.["navigationEndpoint"]?
        .try &.["browseEndpoint"]?
          .try &.["browseId"]?.try &.as_s || ""
    elsif title.try &.== "License"
      contents = contents.try &.["runs"]?
        .try &.as_a[0]?

      params["license"] = contents.try &.["text"]?
        .try &.as_s || ""
    elsif title.try &.== "Licensed to YouTube by"
      params["license"] = contents.try &.["simpleText"]?
        .try &.as_s || ""
    end
  end

  author_info = primary_results.try &.as_a.select { |object| object["videoSecondaryInfoRenderer"]? }[0]?
    .try &.["videoSecondaryInfoRenderer"]?
      .try &.["owner"]?
        .try &.["videoOwnerRenderer"]?

  params["author_thumbnail"] = author_info.try &.["thumbnail"]?
    .try &.["thumbnails"]?
      .try &.as_a[0]?
        .try &.["url"]?
          .try &.as_s || ""

  params["sub_count_text"] = author_info.try &.["subscriberCountText"]?
    .try &.["simpleText"]?
      .try &.as_s.gsub(/\D/, "") || "0"

  return params
end

def extract_player_config(body, html)
  params = HTTP::Params.new

  if md = body.match(/'XSRF_TOKEN': "(?<session_token>[A-Za-z0-9\_\-\=]+)"/)
    params["session_token"] = md["session_token"]
  end

  if md = body.match(/'RELATED_PLAYER_ARGS': (?<rvs>{"rvs":"[^"]+"})/)
    params["rvs"] = JSON.parse(md["rvs"])["rvs"].as_s
  end

  html_info = body.match(/ytplayer\.config = (?<info>.*?);ytplayer\.load/).try &.["info"]

  if html_info
    JSON.parse(html_info)["args"].as_h.each do |key, value|
      params[key] = value.to_s
    end
  else
    error_message = html.xpath_node(%q(//h1[@id="unavailable-message"]))
    if error_message
      params["reason"] = error_message.content.strip
    else
      params["reason"] = "Could not extract video info."
    end
  end

  return params
end

def fetch_video(id, proxies, region)
  client = make_client(YT_URL, proxies, region)
  response = client.get("/watch?v=#{id}&gl=US&hl=en&disable_polymer=1&has_verified=1&bpctr=9999999999")

  if md = response.headers["location"]?.try &.match(/v=(?<id>[a-zA-Z0-9_-]{11})/)
    raise VideoRedirect.new(md["id"])
  end

  html = XML.parse_html(response.body)
  info = extract_player_config(response.body, html)
  info["cookie"] = response.cookies.to_h.map { |name, cookie| "#{name}=#{cookie.value}" }.join("; ")

  # Try to use proxies for region-blocked videos
  if info["reason"]? && info["reason"].includes? "your country"
    bypass_channel = Channel({XML::Node, HTTP::Params} | Nil).new

    proxies.each do |proxy_region, list|
      spawn do
        client = make_client(YT_URL, proxies, proxy_region)
        proxy_response = client.get("/watch?v=#{id}&gl=US&hl=en&disable_polymer=1&has_verified=1&bpctr=9999999999")

        proxy_html = XML.parse_html(proxy_response.body)
        proxy_info = extract_player_config(proxy_response.body, proxy_html)

        if !proxy_info["reason"]?
          proxy_info["region"] = proxy_region
          proxy_info["cookie"] = proxy_response.cookies.to_h.map { |name, cookie| "#{name}=#{cookie.value}" }.join("; ")
          bypass_channel.send({proxy_html, proxy_info})
        else
          bypass_channel.send(nil)
        end
      end
    end

    proxies.size.times do
      response = bypass_channel.receive
      if response
        html, info = response
        break
      end
    end
  end

  # Try to pull streams from embed URL
  if info["reason"]?
    embed_page = client.get("/embed/#{id}").body
    sts = embed_page.match(/"sts"\s*:\s*(?<sts>\d+)/).try &.["sts"]?
    sts ||= ""
    embed_info = HTTP::Params.parse(client.get("/get_video_info?video_id=#{id}&eurl=https://youtube.googleapis.com/v/#{id}&gl=US&hl=en&disable_polymer=1&sts=#{sts}").body)

    if !embed_info["reason"]?
      embed_info.each do |key, value|
        info[key] = value.to_s
      end
    else
      raise info["reason"]
    end
  end

  if info["errorcode"]?.try &.== "2"
    raise "Video unavailable."
  end

  if !info["title"]?
    raise "Video unavailable."
  end

  title = info["title"]
  author = info["author"]
  ucid = info["ucid"]

  views = html.xpath_node(%q(//meta[@itemprop="interactionCount"]))
  views = views.try &.["content"].to_i64?
  views ||= 0_i64

  likes = html.xpath_node(%q(//button[@title="I like this"]/span))
  likes = likes.try &.content.delete(",").try &.to_i?
  likes ||= 0

  dislikes = html.xpath_node(%q(//button[@title="I dislike this"]/span))
  dislikes = dislikes.try &.content.delete(",").try &.to_i?
  dislikes ||= 0

  avg_rating = (likes.to_f/(likes.to_f + dislikes.to_f) * 4 + 1)
  avg_rating = avg_rating.nan? ? 0.0 : avg_rating
  info["avg_rating"] = "#{avg_rating}"

  description = html.xpath_node(%q(//p[@id="eow-description"]))
  description = description ? description.to_xml(options: XML::SaveOptions::NO_DECL) : ""

  wilson_score = ci_lower_bound(likes, likes + dislikes)

  published = html.xpath_node(%q(//meta[@itemprop="datePublished"])).try &.["content"]
  published ||= Time.now.to_s("%Y-%m-%d")
  published = Time.parse(published, "%Y-%m-%d", Time::Location.local)

  allowed_regions = html.xpath_node(%q(//meta[@itemprop="regionsAllowed"])).try &.["content"].split(",")
  allowed_regions ||= [] of String

  is_family_friendly = html.xpath_node(%q(//meta[@itemprop="isFamilyFriendly"])).try &.["content"] == "True"
  is_family_friendly ||= true

  genre = html.xpath_node(%q(//meta[@itemprop="genre"])).try &.["content"]
  genre ||= ""

  genre_url = html.xpath_node(%(//ul[contains(@class, "watch-info-tag-list")]/li/a[text()="#{genre}"])).try &.["href"]

  # Sometimes YouTube tries to link to invalid/missing channels, so we fix that here
  case genre
  when "Education"
    genre_url = "/channel/UCdxpofrI-dO6oYfsqHDHphw"
  when "Gaming"
    genre_url = "/channel/UCOpNcN46UbXVtpKMrmU4Abg"
  when "Movies"
    genre_url = "/channel/UClgRkhTL3_hImCAmdLfDE4g"
  when "Nonprofits & Activism"
    genre_url = "/channel/UCfFyYRYslvuhwMDnx6KjUvw"
  when "Trailers"
    genre_url = "/channel/UClgRkhTL3_hImCAmdLfDE4g"
  end
  genre_url ||= ""

  license = html.xpath_node(%q(//h4[contains(text(),"License")]/parent::*/ul/li))
  if license
    license = license.content
  else
    license = ""
  end

  sub_count_text = html.xpath_node(%q(//span[contains(@class, "yt-subscriber-count")]))
  if sub_count_text
    sub_count_text = sub_count_text["title"]
  else
    sub_count_text = "0"
  end

  author_thumbnail = html.xpath_node(%(//span[@class="yt-thumb-clip"]/img))
  if author_thumbnail
    author_thumbnail = author_thumbnail["data-thumb"]
  else
    author_thumbnail = ""
  end

  video = Video.new(id, info, Time.now, title, views, likes, dislikes, wilson_score, published, description,
    nil, author, ucid, allowed_regions, is_family_friendly, genre, genre_url, license, sub_count_text, author_thumbnail)

  return video
end

def itag_to_metadata?(itag : String)
  return VIDEO_FORMATS[itag]?
end

def process_video_params(query, preferences)
  annotations = query["iv_load_policy"]?.try &.to_i?
  autoplay = query["autoplay"]?.try &.to_i?
  continue = query["continue"]?.try &.to_i?
  continue_autoplay = query["continue_autoplay"]?.try &.to_i?
  listen = query["listen"]? && (query["listen"] == "true" || query["listen"] == "1").to_unsafe
  local = query["local"]? && (query["local"] == "true").to_unsafe
  preferred_captions = query["subtitles"]?.try &.split(",").map { |a| a.downcase }
  quality = query["quality"]?
  region = query["region"]?
  related_videos = query["related_videos"]?
  speed = query["speed"]?.try &.to_f?
  video_loop = query["loop"]?.try &.to_i?
  volume = query["volume"]?.try &.to_i?

  if preferences
    # region ||= preferences.region
    annotations ||= preferences.annotations.to_unsafe
    autoplay ||= preferences.autoplay.to_unsafe
    continue ||= preferences.continue.to_unsafe
    continue_autoplay ||= preferences.continue_autoplay.to_unsafe
    listen ||= preferences.listen.to_unsafe
    local ||= preferences.local.to_unsafe
    preferred_captions ||= preferences.captions
    quality ||= preferences.quality
    related_videos ||= preferences.related_videos.to_unsafe
    speed ||= preferences.speed
    video_loop ||= preferences.video_loop.to_unsafe
    volume ||= preferences.volume
  end

  annotations ||= CONFIG.default_user_preferences.annotations.to_unsafe
  autoplay ||= CONFIG.default_user_preferences.autoplay.to_unsafe
  continue ||= CONFIG.default_user_preferences.continue.to_unsafe
  continue_autoplay ||= CONFIG.default_user_preferences.continue_autoplay.to_unsafe
  listen ||= CONFIG.default_user_preferences.listen.to_unsafe
  local ||= CONFIG.default_user_preferences.local.to_unsafe
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

  if query["t"]?
    video_start = decode_time(query["t"])
  end
  video_start ||= 0
  if query["time_continue"]?
    video_start = decode_time(query["time_continue"])
  end
  video_start ||= 0
  if query["start"]?
    video_start = decode_time(query["start"])
  end

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

  params = VideoPreferences.new(
    annotations: annotations,
    autoplay: autoplay,
    continue: continue,
    continue_autoplay: continue_autoplay,
    controls: controls,
    listen: listen,
    local: local,
    preferred_captions: preferred_captions,
    quality: quality,
    raw: raw,
    region: region,
    related_videos: related_videos,
    speed: speed,
    video_end: video_end,
    video_loop: video_loop,
    video_start: video_start,
    volume: volume,
  )

  return params
end

def build_thumbnails(id, config, kemal_config)
  return {
    {name: "maxres", host: "#{make_host_url(config, kemal_config)}", url: "maxres", height: 720, width: 1280},
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

def generate_thumbnails(json, id, config, kemal_config)
  json.array do
    build_thumbnails(id, config, kemal_config).each do |thumbnail|
      json.object do
        json.field "quality", thumbnail[:name]
        json.field "url", "#{thumbnail[:host]}/vi/#{id}/#{thumbnail["url"]}.jpg"
        json.field "width", thumbnail[:width]
        json.field "height", thumbnail[:height]
      end
    end
  end
end

def generate_storyboards(json, id, storyboards, config, kemal_config)
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
