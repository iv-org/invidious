require "http/client"
require "json"
require "kemal"
require "pg"
require "xml"

class AdaptiveFmts
  JSON.mapping(
    clen: Int32,
    url: String,
    lmt: Int64,
    index: String,
    fps: Int32,
    itag: Int32,
    projection_type: Int32,
    size: String,
    init: String,
    quality_label: String,
    bitrate: Int32,
    type: String
  )
end

class URLEncodedFmtStreamMap
  JSON.mapping(
    url: String,
    itag: Int32,
    fallback_host: String,
    quality: String,
    type: String
  )
end

class CaptionTracks
  JSON.mapping(
    v: String,
    lc: String,
    t: String,
    u: String
  )
end

class CaptionTranslationLanguages
  JSON.mapping(
    lc: String,
    n: String
  )
end

class VideoInfo
  JSON.mapping(
    cver: String,
    length_seconds: Int32,
    iurlhq720: String,
    vm: String,
    ypc_ad_indicator: Int32,
    hash_cc: Bool,
    dashmpd: String,
    iv3_module: Int32,
    iurlmq: String,
    no_get_video_log: Int32,
    cc_font: Int32,
    allowed_ads: String,
    oid: String,
    iv_invideo_url: String,
    cc_asr: Int32,
    relative_loudness: Float64,
    video_verticals: String,
    default_audio_track_index: Int32,
    loudness: Float64,
    ptchn: String,
    csn: String,
    pltype: String,
    author: String,
    # caption_audio_tracks:
    videostats_playback_base_url: String,
    root_ve_type: String,
    muted: Int32,
    cc3_module: Int32,
    adaptive_fmts: AdaptiveFmts,
    fmt_list: Array(String),
    allow_embed: Int32,
    iurlhq: String,
    use_cipher_signature: Bool,
    status: String,
    video_id: String,
    idpj: Int32,
    iurlhmaxres: String,
    short_view_count_text: String,
    iv_load_policy: Int32,
    plid: String,
    vss_host: String,
    ttsurl: String,
    token: String,
    account_playback_token: String,
    of: String,
    iurl: String,
    iurlsd: String,
    c: String,
    timestamp: Int32,
    url_encoded_fmt_stream_map: URLEncodedFmtStreamMap,
    allow_ratings: Int32,
    view_count: Int64,
    title: String,
    caption_tracks: CaptionTracks,
    fexp: Array(String),
    storyboard_spec: String,
    keywords: Array(String),
    ucid: String,
    remarketing_url: String,
    caption_translation_languages: CaptionTranslationLanguages,
    avg_rating: Float64,
    is_listed: Int32,
    ptk: String,
    cl: Int32,
    watermark: Array(String),
    ldpj: Int32,
    tmi: Int32,
    eventid: String,
    thumbnail_url: String
  )
end


macro templated(filename)
  render "src/views/#{{{filename}}}.ecr", "src/views/layout.ecr"
end

context = OpenSSL::SSL::Context::Client.insecure
client = HTTP::Client.new("www.youtube.com", 443, context)


video_id = "Vufba_ZcoR0"
video_info = client.get("/get_video_info?video_id=#{video_id}&el=info&ps=default&eurl=&gl=US&hl=en").body

p VideoInfo.from_json(video_info)


get "/" do |env|
  templated "index"
end

get "/watch/:video_id" do |env|
  video_id = env.params.url["video_id"]

  client = HTTP::Client.new("www.youtube.com", 443, context)
  video_info = client.get("/get_video_info?video_id=#{video_id}&el=info&ps=default&eurl=&gl=US&hl=en").body
  video_info = HTTP::Params.parse(video_info)
  pageContent = client.get("/watch?v=#{video_id}").body
  doc = XML.parse(pageContent)

  fmt_stream = [] of HTTP::Params
  video_info["url_encoded_fmt_stream_map"].split(",") do |string|
    fmt_stream << HTTP::Params.parse(string)
  end

  fmt_stream.reverse! # We want lowest quality first
  # css query [title="I like this"] > span
  likes = doc.xpath_node(%q(//button[@title="I like this"]/span))
  if likes
    likes = likes.content.delete(",").to_i
  else
    likes = 1
  end

  # css query [title="I dislike this"] > span
  dislikes = doc.xpath_node(%q(//button[@title="I dislike this"]/span))
  if dislikes
    dislikes = dislikes.content.delete(",").to_i
  else
    dislikes = 1
  end

  engagement = ((dislikes.to_f32 + likes.to_f32)*100 / video_info["view_count"].to_f32).significant(2)
  calculated_rating = likes.to_f32/(likes.to_f32 + dislikes.to_f32)*4 + 1

  templated "watch"
end

public_folder "assets"

Kemal.run
