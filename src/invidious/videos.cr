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
  "Norwegian",
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

class Video
  property player_json : JSON::Any?

  module HTTPParamConverter
    def self.from_rs(rs)
      HTTP::Params.parse(rs.read(String))
    end
  end

  def allow_ratings
    allow_ratings = player_response["videoDetails"].try &.["allowRatings"]?.try &.as_bool

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
    is_listed = player_response["videoDetails"].try &.["isCrawlable"]?.try &.as_bool

    if is_listed.nil?
      return true
    end

    return is_listed
  end

  def is_upcoming
    is_upcoming = player_response["videoDetails"].try &.["isUpcoming"]?.try &.as_bool

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
                .try &.["scheduledStartTime"].as_s.to_i64
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

  add_mapping({
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

class Caption
  JSON.mapping(
    name: CaptionName,
    baseUrl: String,
    languageCode: String
  )
end

class CaptionName
  JSON.mapping(
    simpleText: String,
  )
end

class VideoRedirect < Exception
end

def get_video(id, db, proxies = {} of String => Array({ip: String, port: Int32}), refresh = true, region = nil)
  if db.query_one?("SELECT EXISTS (SELECT true FROM videos WHERE id = $1)", id, as: Bool) && !region
    video = db.query_one("SELECT * FROM videos WHERE id = $1", id, as: Video)

    # If record was last updated over 10 minutes ago, refresh (expire param in response lasts for 6 hours)
    if refresh && Time.now - video.updated > 10.minutes
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

def extract_player_config(body, html)
  params = HTTP::Params.new

  if md = body.match(/'XSRF_TOKEN': "(?<session_token>[A-Za-z0-9\_\-\=]+)"/)
    params["session_token"] = md["session_token"]
  end

  if md = body.match(/itct=(?<itct>[^"]+)"/)
    params["itct"] = md["itct"]
  end

  if md = body.match(/'COMMENTS_TOKEN': "(?<ctoken>[^"]+)"/)
    params["ctoken"] = md["ctoken"]
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
  description = description ? description.to_xml : ""

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
  autoplay = query["autoplay"]?.try &.to_i?
  continue = query["continue"]?.try &.to_i?
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
    autoplay ||= preferences.autoplay.to_unsafe
    continue ||= preferences.continue.to_unsafe
    listen ||= preferences.listen.to_unsafe
    local ||= preferences.local.to_unsafe
    preferred_captions ||= preferences.captions
    quality ||= preferences.quality
    related_videos ||= preferences.related_videos.to_unsafe
    speed ||= preferences.speed
    video_loop ||= preferences.video_loop.to_unsafe
    volume ||= preferences.volume
  end

  autoplay ||= DEFAULT_USER_PREFERENCES.autoplay.to_unsafe
  continue ||= DEFAULT_USER_PREFERENCES.continue.to_unsafe
  listen ||= DEFAULT_USER_PREFERENCES.listen.to_unsafe
  local ||= DEFAULT_USER_PREFERENCES.local.to_unsafe
  preferred_captions ||= DEFAULT_USER_PREFERENCES.captions
  quality ||= DEFAULT_USER_PREFERENCES.quality
  related_videos ||= DEFAULT_USER_PREFERENCES.related_videos.to_unsafe
  speed ||= DEFAULT_USER_PREFERENCES.speed
  video_loop ||= DEFAULT_USER_PREFERENCES.video_loop.to_unsafe
  volume ||= DEFAULT_USER_PREFERENCES.volume

  autoplay = autoplay == 1
  continue = continue == 1
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
  controls = controls == 1

  params = {
    autoplay:           autoplay,
    continue:           continue,
    controls:           controls,
    listen:             listen,
    local:              local,
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
  }

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
