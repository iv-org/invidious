require "http/client"
require "json"
require "kemal"
require "pg"
require "xml"
require "time"

# Get rid of everything except video_info, video_html, video_id

# class AdaptiveFmts
#   JSON.mapping(
#     clen: Int32,
#     url: String,
#     lmt: Int64,
#     index: String,
#     fps: Int32,
#     itag: Int32,
#     projection_type: Int32,
#     size: String,
#     init: String,
#     quality_label: String,
#     bitrate: Int32,
#     type: String
#   )
# end

# class URLEncodedFmtStreamMap
#   JSON.mapping(
#     url: String,
#     itag: Int32,
#     fallback_host: String,
#     quality: String,
#     type: String
#   )
# end

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

class Video
  getter last_updated : Time
  getter video_id : String
  getter video_info : String
  getter video_html : String
  getter views : String
  getter likes : Int32
  getter dislikes : Int32
  getter rating : Float64
  getter description : String

  def initialize(last_updated, video_id, video_info, video_html, views, likes, dislikes, rating, description)
    @last_updated = last_updated
    @video_id = video_id
    @video_info = video_info
    @video_html = video_html
    @views = views
    @likes = likes
    @dislikes = dislikes
    @rating = rating
    @description = description
  end

  def to_a
    return [@last_updated, @video_id, @video_info, @video_html, @views, @likes, @dislikes, @rating, @description]
  end

  DB.mapping({
    last_updated: Time,
    video_id:     String,
    video_info:   String,
    video_html:   String,
    views:        Int64,
    likes:        Int32,
    dislikes:     Int32,
    rating:       Float64,
    description:  String,
  })
end

def get_video(video_id, context)
  client = HTTP::Client.new("www.youtube.com", 443, context)
  video_info = client.get("/get_video_info?video_id=#{video_id}&el=info&ps=default&eurl=&gl=US&hl=en").body
  info = HTTP::Params.parse(video_info)
  video_html = client.get("/watch?v=#{video_id}").body
  html = XML.parse(video_html)
  views = info["view_count"].to_i64
  rating = info["avg_rating"].to_f64

  likes = html.xpath_node(%q(//button[@title="I like this"]/span))
  if likes
    likes = likes.content.delete(",").to_i
  else
    likes = 1
  end

  dislikes = html.xpath_node(%q(//button[@title="I dislike this"]/span))
  if dislikes
    dislikes = dislikes.content.delete(",").to_i
  else
    dislikes = 1
  end

  description = html.xpath_node(%q(//p[@id="eow-description"]))
  if description
    description = description.to_xml
  else
    description = ""
  end

  video_record = Video.new(Time.now, video_id, video_info, video_html, views, likes, dislikes, rating, description)

  return video_record
end

# See http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
def ci_lower_bound(pos, n)
  if n == 0
    return 0
  end

  # z value here represents a confidence level of 0.95
  z = 1.96
  phat = 1.0*pos/n

  return (phat + z*z/(2*n) - z * Math.sqrt((phat*(1 - phat) + z*z/(4*n))/n))/(1 + z*z/n)
end

get "/" do |env|
  templated "index"
end

pg = DB.open "postgres://kemal:kemal@localhost:5432/invidious"
context = OpenSSL::SSL::Context::Client.insecure

get "/watch" do |env|
  video_id = env.params.query["v"]

  if pg.query_one?("select exists (select true from videos where video_id = $1)", video_id, as: Bool)
    video_record = pg.query_one("select * from videos where video_id = $1", video_id, as: Video)

    # If record was last updated more than 1 hour ago, refresh
    if Time.now - video_record.last_updated > Time::Span.new(1, 0, 0, 0)
      video_record = get_video(video_id, context)
      pg.exec("update videos set last_updated = $1, video_info = $3, video_html = $4,\
      views = $5, likes = $6, dislikes = $7, rating = $8, description = $9 where video_id = $2",
      video_record.to_a)
  end
  else
    client = HTTP::Client.new("www.youtube.com", 443, context)
    video_info = client.get("/get_video_info?video_id=#{video_id}&el=info&ps=default&eurl=&gl=US&hl=en").body
    info = HTTP::Params.parse(video_info)

    if info["reason"]?
      error_message = info["reason"]
      next templated "error"
    end

    video_record = get_video(video_id, context)
    pg.exec("insert into videos values ($1,$2,$3,$4,$5,$6,$7,$8, $9)", video_record.to_a)
  end

  # last_updated, video_id, video_info, video_html, views, likes, dislikes, rating
  video_info = HTTP::Params.parse(video_record.video_info)
  video_html = XML.parse(video_record.video_html)

  fmt_stream = [] of HTTP::Params
  video_info["url_encoded_fmt_stream_map"].split(",") do |string|
    fmt_stream << HTTP::Params.parse(string)
  end

  fmt_stream.reverse! # We want lowest quality first

  related_videos = video_html.xpath_nodes(%q(//li/div/a[contains(@class,"content-link")]/@href))

  if related_videos.empty?
    related_videos = video_html.xpath_nodes(%q(//ytd-compact-video-renderer/div/a/@href))
  end

  likes = video_record.likes.to_f
  dislikes = video_record.dislikes.to_f
  views = video_record.views.to_f

  engagement = ((dislikes + likes)/views * 100)
  calculated_rating = (likes/(likes + dislikes) * 4 + 1)

  templated "watch"
end

get "/search" do |env|
  query = URI.escape(env.params.query["q"])
  client = HTTP::Client.new("www.youtube.com", 443, context)
  results_html = client.get("https://www.youtube.com/results?q=#{query}&page=1").body
  html = XML.parse(results_html)

  videos = html.xpath_nodes(%q(//div[@class="style-scope ytd-item-section-renderer"]/ytd-video-renderer))
  channels = html.xpath_nodes(%q(//div[@class="style-scope ytd-item-section-renderer"]/ytd-channel-renderer))

  if videos.empty?
    videos = html.xpath_nodes(%q(//div[contains(@class,"yt-lockup-video")]/div/div[contains(@class,"yt-lockup-thumbnail")]/a/@href))
    channels = html.xpath_nodes(%q(//div[contains(@class,"yt-lockup-channel")]/div/div[contains(@class,"yt-lockup-thumbnail")]/a/@href))
  end

  templated "search"
end

error 404 do |env|
  templated "index"
end

error 500 do |env|
  templated "index"
end

public_folder "assets"

Kemal.run
