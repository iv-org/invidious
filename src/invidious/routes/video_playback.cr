module Invidious::Routes::VideoPlayback
  # /videoplayback
  def self.get_video_playback(env)
    locale = env.get("preferences").as(Preferences).locale
    query_params = env.params.query

    fvip = query_params["fvip"]? || "3"
    mns = query_params["mn"]?.try &.split(",")
    mns ||= [] of String

    if query_params["region"]?
      region = query_params["region"]
      query_params.delete("region")
    end

    if query_params["host"]? && !query_params["host"].empty?
      host = query_params["host"]
      query_params.delete("host")
    else
      host = "r#{fvip}---#{mns.pop}.googlevideo.com"
    end

    # Sanity check, to avoid being used as an open proxy
    if !host.matches?(/[\w-]+.googlevideo.com/)
      return error_template(400, "Invalid \"host\" parameter.")
    end

    host = "https://#{host}"
    url = "/videoplayback?#{query_params}"

    headers = HTTP::Headers.new
    REQUEST_HEADERS_WHITELIST.each do |header|
      if env.request.headers[header]?
        headers[header] = env.request.headers[header]
      end
    end

    client = make_client(URI.parse(host), region)
    response = HTTP::Client::Response.new(500)
    error = ""
    5.times do
      begin
        response = client.head(url, headers)

        if response.headers["Location"]?
          location = URI.parse(response.headers["Location"])
          env.response.headers["Access-Control-Allow-Origin"] = "*"

          new_host = "#{location.scheme}://#{location.host}"
          if new_host != host
            host = new_host
            client.close
            client = make_client(URI.parse(new_host), region)
          end

          url = "#{location.request_target}&host=#{location.host}#{region ? "&region=#{region}" : ""}"
        else
          break
        end
      rescue Socket::Addrinfo::Error
        if !mns.empty?
          mn = mns.pop
        end
        fvip = "3"

        host = "https://r#{fvip}---#{mn}.googlevideo.com"
        client = make_client(URI.parse(host), region)
      rescue ex
        error = ex.message
      end
    end

    if response.status_code >= 400
      env.response.content_type = "text/plain"
      haltf env, response.status_code
    end

    if url.includes? "&file=seg.ts"
      if CONFIG.disabled?("livestreams")
        return error_template(403, "Administrator has disabled this endpoint.")
      end

      begin
        client.get(url, headers) do |resp|
          resp.headers.each do |key, value|
            if !RESPONSE_HEADERS_BLACKLIST.includes?(key.downcase)
              env.response.headers[key] = value
            end
          end

          env.response.headers["Access-Control-Allow-Origin"] = "*"

          if location = resp.headers["Location"]?
            location = URI.parse(location)
            location = "#{location.request_target}&host=#{location.host}"

            if region
              location += "&region=#{region}"
            end

            return env.redirect location
          end

          IO.copy(resp.body_io, env.response)
        end
      rescue ex
      end
    else
      if query_params["title"]? && CONFIG.disabled?("downloads") ||
         CONFIG.disabled?("dash")
        return error_template(403, "Administrator has disabled this endpoint.")
      end

      request_range = env.request.headers["Range"]?
      range_start, range_end = parse_range(request_range)
      headers["Range"] = "bytes=#{range_start}-#{range_end}"

      # Try once normally, and retry if a region is required.
      2.times do
        begin
          client.get(url, headers) do |resp|
            if !env.request.headers["Range"]? && resp.status_code == 206
              env.response.status_code = 200
            else
              env.response.status_code = resp.status_code
            end

            resp.headers.each do |key, value|
              if !RESPONSE_HEADERS_BLACKLIST.includes?(key.downcase) && key.downcase != "content-range"
                env.response.headers[key] = value
              end
            end

            env.response.headers["Access-Control-Allow-Origin"] = "*"

            if location = resp.headers["Location"]?
              location = URI.parse(location)
              location = "#{location.request_target}&host=#{location.host}#{region ? "&region=#{region}" : ""}"

              env.redirect location
              break
            end

            if title = query_params["title"]?
              # https://blog.fastmail.com/2011/06/24/download-non-english-filenames/
              env.response.headers["Content-Disposition"] = "attachment; filename=\"#{URI.encode_www_form(title)}\"; filename*=UTF-8''#{URI.encode_www_form(title)}"
            end

            proxy_file(resp, env)
          end
          break
        rescue ex
          if ex.message != "Error reading socket: Connection reset by peer"
            break
          else
            client.close
            client = make_client(URI.parse(host), region)
          end
        end
      end
    end

    client.close
  end

  # /videoplayback/*
  def self.get_video_playback_greedy(env)
    path = env.request.path

    path = path.lchop("/videoplayback/")
    path = path.rchop("/")

    path = path.gsub(/mime\/\w+\/\w+/) do |mimetype|
      mimetype = mimetype.split("/")
      mimetype[0] + "/" + mimetype[1] + "%2F" + mimetype[2]
    end

    path = path.split("/")

    raw_params = {} of String => Array(String)
    path.each_slice(2) do |pair|
      key, value = pair
      value = URI.decode_www_form(value)

      if raw_params[key]?
        raw_params[key] << value
      else
        raw_params[key] = [value]
      end
    end

    query_params = HTTP::Params.new(raw_params)

    env.response.headers["Access-Control-Allow-Origin"] = "*"
    return env.redirect "/videoplayback?#{query_params}"
  end

  # /videoplayback/* && /videoplayback/*
  def self.options_video_playback(env)
    env.response.headers.delete("Content-Type")
    env.response.headers["Access-Control-Allow-Origin"] = "*"
    env.response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Range"
  end

  # /latest_version
  #
  # YouTube /videoplayback links expire after 6 hours,
  # so we have a mechanism here to redirect to the latest version
  def self.latest_version(env)
    if env.params.query["download_widget"]?
      download_widget = JSON.parse(env.params.query["download_widget"])

      id = download_widget["id"].as_s
      title = URI.decode_www_form(download_widget["title"].as_s)

      if label = download_widget["label"]?
        return env.redirect "/api/v1/captions/#{id}?label=#{label}&title=#{title}"
      else
        itag = download_widget["itag"].as_s.to_i
        local = "true"
      end
    end

    id ||= env.params.query["id"]?
    itag ||= env.params.query["itag"]?.try &.to_i

    region = env.params.query["region"]?

    local ||= env.params.query["local"]?
    local ||= "false"
    local = local == "true"

    if !id || !itag
      haltf env, status_code: 400, response: "TESTING"
    end

    video = get_video(id, region: region)

    fmt = video.fmt_stream.find(nil) { |f| f["itag"].as_i == itag } || video.adaptive_fmts.find(nil) { |f| f["itag"].as_i == itag }
    url = fmt.try &.["url"]?.try &.as_s

    if !url
      haltf env, status_code: 404
    end

    url = URI.parse(url).request_target.not_nil! if local
    url = "#{url}&title=#{title}" if title

    return env.redirect url
  end
end
