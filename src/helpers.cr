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

def elapsed_text(elapsed)
  millis = elapsed.total_milliseconds
  return "#{millis.round(2)}ms" if millis >= 1

  "#{(millis * 1000).round(2)}µs"
end

def get_client
  while POOL.empty?
    sleep rand(0..10).milliseconds
  end

  return POOL.shift
end

def fetch_video(id)
  # Grab connection from pool
  client = get_client

  info = client.get("/get_video_info?video_id=#{id}&el=detailpage&ps=default&eurl=&gl=US&hl=en").body
  info = HTTP::Params.parse(info)

  html = client.get("/watch?v=#{id}").body
  html = XML.parse_html(html)

  if info["reason"]?
    raise info["reason"]
  end

  # Return connection to pool
  POOL << client

  video = Video.new(id, info, html, Time.now)

  return video
end

def get_video(id, refresh = true)
  if PG_DB.query_one?("SELECT EXISTS (SELECT true FROM videos WHERE id = $1)", id, as: Bool)
    video = PG_DB.query_one("SELECT * FROM videos WHERE id = $1", id, as: Video)

    # If record was last updated more than 5 hours ago, refresh (expire param in response lasts for 6 hours)
    if refresh && Time.now - video.updated > Time::Span.new(0, 5, 0, 0)
      video = fetch_video(id)
      PG_DB.exec("UPDATE videos SET info = $2, html = $3, updated = $4 WHERE id = $1", video.to_a)
    end
  else
    video = fetch_video(id)
    PG_DB.exec("INSERT INTO videos VALUES ($1, $2, $3, $4)", video.to_a)
  end

  return video
end
