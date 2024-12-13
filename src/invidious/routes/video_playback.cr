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

    # See: https://github.com/iv-org/invidious/issues/3302
    range_header = env.request.headers["Range"]?
    if range_header.nil?
      range_for_head = query_params["range"]? || "0-640"
      headers["Range"] = "bytes=#{range_for_head}"
    end

    client = make_client(URI.parse(host), region, force_resolve: true)
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
            client = make_client(URI.parse(new_host), region, force_resolve: true)
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
        client = make_client(URI.parse(host), region, force_resolve: true)
      rescue ex
        error = ex.message
      end
    end

    # Remove the Range header added previously.
    headers.delete("Range") if range_header.nil?

    playback_statistics = get_playback_statistic()
    playback_statistics["totalRequests"] += 1

    if response.status_code >= 400
      env.response.content_type = "text/plain"
      haltf env, response.status_code
    else
      playback_statistics["successfulRequests"] += 1
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
            url = Invidious::HttpServer::Utils.proxy_video_url(location, region: region)
            return env.redirect url
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

      content_length = nil
      first_chunk = true
      range_start, range_end = parse_range(env.request.headers["Range"]?)
      chunk_start = range_start
      chunk_end = range_end

      if !chunk_end || chunk_end - chunk_start > HTTP_CHUNK_SIZE
        chunk_end = chunk_start + HTTP_CHUNK_SIZE - 1
      end

      # TODO: Record bytes written so we can restart after a chunk fails
      loop do
        if !range_end && content_length
          range_end = content_length
        end

        if range_end && chunk_start > range_end
          break
        end

        if range_end && chunk_end > range_end
          chunk_end = range_end
        end

        headers["Range"] = "bytes=#{chunk_start}-#{chunk_end}"

        begin
          client.get(url, headers) do |resp|
            if first_chunk
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
                filename = URI.encode_www_form(title, space_to_plus: false)
                header = "attachment; filename=\"#{filename}\"; filename*=UTF-8''#{filename}"
                env.response.headers["Content-Disposition"] = header
              end

              if !resp.headers.includes_word?("Transfer-Encoding", "chunked")
                content_length = resp.headers["Content-Range"].split("/")[-1].to_i64
                if env.request.headers["Range"]?
                  env.response.headers["Content-Range"] = "bytes #{range_start}-#{range_end || (content_length - 1)}/#{content_length}"
                  env.response.content_length = ((range_end.try &.+ 1) || content_length) - range_start
                else
                  env.response.content_length = content_length
                end
              end
            end

            proxy_file(resp, env)
          end
        rescue ex
          if ex.message != "Error reading socket: Connection reset by peer"
            break
          else
            client.close
            client = make_client(URI.parse(host), region, force_resolve: true)
          end
        end

        chunk_start = chunk_end + 1
        chunk_end += HTTP_CHUNK_SIZE
        first_chunk = false
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
    id = env.params.query["id"]?
    itag = env.params.query["itag"]?.try &.to_i?

    # Sanity checks
    if id.nil? || id.size != 11 || !id.matches?(/^[\w-]+$/)
      return error_template(400, "Invalid video ID")
    end

    if !itag.nil? && (itag <= 0 || itag >= 1000)
      return error_template(400, "Invalid itag")
    end

    region = env.params.query["region"]?
    local = (env.params.query["local"]? == "true")

    title = env.params.query["title"]?

    if title && CONFIG.disabled?("downloads")
      return error_template(403, "Administrator has disabled this endpoint.")
    end

    begin
      video = get_video(id, region: region)
    rescue ex : NotFoundException
      return error_template(404, ex)
    rescue ex
      return error_template(500, ex)
    end

    if itag.nil?
      fmt = video.fmt_stream[-1]?
    else
      fmt = video.fmt_stream.find(nil) { |f| f["itag"].as_i == itag } || video.adaptive_fmts.find(nil) { |f| f["itag"].as_i == itag }
    end
    url = fmt.try &.["url"]?.try &.as_s

    if !url
      haltf env, status_code: 404
    end

    if local
      url = URI.parse(url).request_target.not_nil!
      url += "&title=#{URI.encode_www_form(title, space_to_plus: false)}" if title
    end

    return env.redirect url
  end
end
