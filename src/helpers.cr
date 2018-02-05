class Video
  module HTTPParamConverter
    def self.from_rs(rs)
      HTTP::Params.parse(rs.read(String))
    end
  end

  module XMLConverter
    def self.from_rs(rs)
      XML.parse_html(rs.read(String))
    end
  end

  def initialize(id, info, html, updated, title, views, likes, dislikes, wilson_score, published)
    @id = id
    @info = info
    @html = html
    @updated = updated
    @title = title
    @views = views
    @likes = likes
    @dislikes = dislikes
    @wilson_score = wilson_score
    @published = published
  end

  def to_a
    return [@id, @info, @html, @updated, @title, @views, @likes, @dislikes, @wilson_score, @published]
  end

  DB.mapping({
    id:   String,
    info: {
      type:      HTTP::Params,
      default:   HTTP::Params.parse(""),
      converter: Video::HTTPParamConverter,
    },
    html: {
      type:      XML::Node,
      default:   XML.parse_html(""),
      converter: Video::XMLConverter,
    },
    updated:      Time,
    title:        String,
    views:        Int64,
    likes:        Int32,
    dislikes:     Int32,
    wilson_score: Float64,
    published:    Time,
  })
end

# See http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
def ci_lower_bound(pos, n)
  if n == 0
    return 0.0
  end

  # z value here represents a confidence level of 0.95
  z = 1.96
  phat = 1.0*pos/n

  return (phat + z*z/(2*n) - z * Math.sqrt((phat*(1 - phat) + z*z/(4*n))/n))/(1 + z*z/n)
end

def elapsed_text(elapsed)
  millis = elapsed.total_milliseconds
  return "#{millis.round(2)}ms" if millis >= 1

  "#{(millis * 1000).round(2)}µs"
end

def get_client(pool)
  while pool.empty?
    sleep rand(0..10).milliseconds
  end

  return pool.shift
end

def fetch_video(id, client)
  begin
    info = client.get("/get_video_info?video_id=#{id}&el=detailpage&ps=default&eurl=&gl=US&hl=en").body
    html = client.get("/watch?v=#{id}").body
  end

  html = XML.parse_html(html)
  info = HTTP::Params.parse(info)

  if info["reason"]?
    info = client.get("/get_video_info?video_id=#{id}&ps=default&eurl=&gl=US&hl=en").body
    info = HTTP::Params.parse(info)
    if info["reason"]?
      raise info["reason"]
    end
  end

  title = info["title"]

  views = info["view_count"].to_i64

  likes = html.xpath_node(%q(//button[@title="I like this"]/span))
  likes = likes ? likes.content.delete(",").to_i : 0

  dislikes = html.xpath_node(%q(//button[@title="I dislike this"]/span))
  dislikes = dislikes ? dislikes.content.delete(",").to_i : 0

  wilson_score = ci_lower_bound(likes, likes + dislikes)

  published = html.xpath_node(%q(//strong[contains(@class,"watch-time-text")]))
  if published
    published = published.content
  else
    raise "Could not find date published"
  end

  published = published.lchop("Published ")
  published = published.lchop("Streamed live ")
  published = published.lchop("Started streaming ")
  published = published.lchop("on ")
  published = published.lchop("Scheduled for ")
    if !published.includes?("ago")
      published = Time.parse(published, "%b %-d, %Y")
    else
      # Time matches format "20 hours ago", "40 minutes ago"...
    delta = published.split(" ")[0].to_i
    case published
    when .includes? "minute"
      published = Time.now - delta.minutes
    when .includes? "hour"
      published = Time.now - delta.hours
  else
      raise "Could not parse #{published}"
  end
  end

  video = Video.new(id, info, html, Time.now, title, views, likes, dislikes, wilson_score, published)

  return video
end

def get_video(id, client, db, refresh = true)
  if db.query_one?("SELECT EXISTS (SELECT true FROM videos WHERE id = $1)", id, as: Bool)
    video = db.query_one("SELECT * FROM videos WHERE id = $1", id, as: Video)

    # If record was last updated over an hour ago, refresh (expire param in response lasts for 6 hours)
    if refresh && Time.now - video.updated > 1.hours
      video = fetch_video(id, client)
      db.exec("UPDATE videos SET info = $2, html = $3, updated = $4,\
       title = $5, views = $6, likes = $7, dislikes = $8, wilson_score = $9, published = $10 WHERE id = $1", video.to_a)
    end
  else
    video = fetch_video(id, client)
    db.exec("INSERT INTO videos VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)", video.to_a)
  end

  return video
end

def search(query, client)
  begin
    html = client.get("https://www.youtube.com/results?q=#{query}&sp=EgIQAVAU").body
  end

  html = XML.parse_html(html)

  html.xpath_nodes(%q(//ol[@class="item-section"]/li)).each do |item|
    root = item.xpath_node(%q(div[contains(@class,"yt-lockup-video")]/div))
    if root
      link = root.xpath_node(%q(div[contains(@class,"yt-lockup-thumbnail")]/a/@href))
      if link
        yield link.content.split("=")[1]
      end
    end
  end
end

def decrypt_signature(a)
  a = a.split("")
  a.delete_at(0..2)
  a = a.reverse
  c = a[0]
  a[0] = a[49 % a.size]
  a[49] = c
  return a.join("")
end