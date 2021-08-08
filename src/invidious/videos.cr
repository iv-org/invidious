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

def extract_video_info(video_id : String, proxy_region : String? = nil, context_screen : String? = nil)
  params = {} of String => JSON::Any

  client_config = YoutubeAPI::ClientConfig.new(proxy_region: proxy_region)
  if context_screen == "embed"
    client_config.client_type = YoutubeAPI::ClientType::WebScreenEmbed
  end

  player_response = YoutubeAPI.player(video_id: video_id, params: "", client_config: client_config)

  if player_response["playabilityStatus"]?.try &.["status"]?.try &.as_s != "OK"
    reason = player_response["playabilityStatus"]["errorScreen"]?.try &.["playerErrorMessageRenderer"]?.try &.["subreason"]?.try { |s|
      s["simpleText"]?.try &.as_s || s["runs"].as_a.map { |r| r["text"] }.join("")
    } || player_response["playabilityStatus"]["reason"].as_s
    params["reason"] = JSON::Any.new(reason)
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
    stream_data = YoutubeAPI.player(video_id: video_id, params: "", client_config: client_config)
    params["streamingData"] = stream_data["streamingData"]? || JSON::Any.new("")
  end

  {"captions", "microformat", "playabilityStatus", "storyboards", "videoDetails"}.each do |f|
    params[f] = player_response[f] if player_response[f]?
  end

  params["relatedVideos"] = (
    player_response
      .dig?("playerOverlays", "playerOverlayRenderer", "endScreen", "watchNextEndScreenRenderer", "results")
      .try &.as_a.compact_map { |r| parse_related r } || \
       player_response
        .dig?("webWatchNextResponseExtensionData", "relatedVideoArgs")
        .try &.as_s.split(",").map { |r|
          r = HTTP::Params.parse(r).to_h
          JSON::Any.new(Hash.zip(r.keys, r.values.map { |v| JSON::Any.new(v) }))
        }
  ).try { |a| JSON::Any.new(a) } || JSON::Any.new([] of JSON::Any)

  primary_results = player_response.try &.["contents"]?.try &.["twoColumnWatchNextResults"]?.try &.["results"]?
    .try &.["results"]?.try &.["contents"]?
  sentiment_bar = primary_results.try &.as_a.select(&.["videoPrimaryInfoRenderer"]?)[0]?
    .try &.["videoPrimaryInfoRenderer"]?
      .try &.["sentimentBar"]?
        .try &.["sentimentBarRenderer"]?
          .try &.["tooltip"]?
            .try &.as_s

  likes, dislikes = sentiment_bar.try &.split(" / ", 2).map &.gsub(/\D/, "").to_i64 || {0_i64, 0_i64}
  params["likes"] = JSON::Any.new(likes)
  params["dislikes"] = JSON::Any.new(dislikes)

  params["descriptionHtml"] = JSON::Any.new(primary_results.try &.as_a.select(&.["videoSecondaryInfoRenderer"]?)[0]?
    .try &.["videoSecondaryInfoRenderer"]?.try &.["description"]?.try &.["runs"]?
      .try &.as_a.try { |t| content_to_comment_html(t).gsub("\n", "<br/>") } || "<p></p>")

  metadata = primary_results.try &.as_a.select(&.["videoSecondaryInfoRenderer"]?)[0]?
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

  author_info = primary_results.try &.as_a.select(&.["videoSecondaryInfoRenderer"]?)[0]?
    .try &.["videoSecondaryInfoRenderer"]?.try &.["owner"]?.try &.["videoOwnerRenderer"]?

  params["authorThumbnail"] = JSON::Any.new(author_info.try &.["thumbnail"]?
    .try &.["thumbnails"]?.try &.as_a[0]?.try &.["url"]?
      .try &.as_s || "")

  params["subCountText"] = JSON::Any.new(author_info.try &.["subscriberCountText"]?
    .try { |t| t["simpleText"]? || t["runs"]?.try &.[0]?.try &.["text"]? }.try &.as_s.split(" ", 2)[0] || "-")

  params
end

def get_video(id, db, refresh = true, region = nil, force_refresh = false)
  if (video = db.query_one?("SELECT * FROM videos WHERE id = $1", id, as: YouTubeStructs::Video)) && !region
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

# TODO make private. All instances of fetching video should be done from get_video() to
# allow for caching.
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

  raise InfoException.new(info["reason"]?.try &.as_s || "") if !info["videoDetails"]?

  video = YouTubeStructs::Video.new({
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

  params = InvidiousStructs::VideoPreferences.new({
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
