require "http/client"
require "json"
require "kemal"
require "pg"
require "xml"
require "time"

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

class Record
end

macro templated(filename)
  render "src/views/#{{{filename}}}.ecr", "src/views/layout.ecr"
end

pg = DB.open "postgres://kemal:kemal@localhost:5432/invidious"
context = OpenSSL::SSL::Context::Client.insecure

get "/" do |env|
  templated "index"
end

def get_record(context, video_id)
  client = HTTP::Client.new("www.youtube.com", 443, context)
  video_info = client.get("/get_video_info?video_id=#{video_id}&el=info&ps=default&eurl=&gl=US&hl=en").body
  info = HTTP::Params.parse(video_info)
  video_html = client.get("/watch?v=#{video_id}").body
  html = XML.parse(video_html)
  views = info["view_count"]
  rating = info["avg_rating"].to_f64

  like = html.xpath_node(%q(//button[@title="I like this"]/span))
  if like
    likes = like.content.delete(",").to_i
  else
    likes = 1
  end

  # css query [title = "I like this"] > span
  # css query [title = "I dislike this"] > span
  dislike = html.xpath_node(%q(//button[@title="I dislike this"]/span))
  if dislike
    dislikes = dislike.content.delete(",").to_i
  else
    dislikes = 1
  end

  args = {Time.now, video_id, video_info, video_html, views, likes, dislikes, rating}
  return args
end

get "/watch/:video_id" do |env|
  video_id = env.params.url["video_id"]

  # last_updated, video_id, video_info, video_html, views, likes, dislikes, rating
  video_record = pg.query_one?("select * from invidious where video_id = $1",
    video_id,
    as: {Time, String, String, String, Int64, Int32, Int32, Float64})

  # If record was last updated more than 5 minutes ago or doesn't exist, refresh
  if video_record.nil?
    video_record = get_record(context, video_id)
    pg.exec("insert into invidious values ($1, $2, $3, $4, $5, $6, $7, $8)",
      get_record(context, video_id).to_a)
  elsif Time.now.epoch - video_record[0].epoch > 300
    video_record = get_record(context, video_id)
    pg.exec("update invidious set last_updated = $1, video_info = $2, video_html = $3,\
      views = $4, likes = $5, dislikes = $6, rating = $7 where video_id = $8",
      video_record.to_a)
  end

  video_info = HTTP::Params.parse(video_record[2])
  video_html = XML.parse(video_record[3])
  views = video_record[4]
  likes = video_record[5]
  dislikes = video_record[6]
  rating = video_record[7]

  fmt_stream = [] of HTTP::Params
  video_info["url_encoded_fmt_stream_map"].split(",") do |string|
    fmt_stream << HTTP::Params.parse(string)
  end

  fmt_stream.reverse! # We want lowest quality first

  likes = likes.to_f
  dislikes = dislikes.to_f
  views = views.to_f

  engagement = ((dislikes + likes)/views * 100).significant(2)
  calculated_rating = likes/(likes + dislikes) * 4 + 1

  likes = likes.to_s
  dislikes = dislikes.to_s
  views = views.to_s

  templated "watch"
end

public_folder "assets"

Kemal.run
