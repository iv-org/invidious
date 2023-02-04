module Invidious::Routes::API::Manifest
  # /api/manifest/dash/id/:id
  def self.get_dash_video_id(env)
    env.response.headers.add("Access-Control-Allow-Origin", "*")
    env.response.content_type = "application/dash+xml"

    local = (env.params.query["local"]? == "true")
    id = env.params.url["id"]
    region = env.params.query["region"]?

    # Since some implementations create playlists based on resolution regardless of different codecs,
    # we can opt to only add a source to a representation if it has a unique height within that representation
    unique_res = env.params.query["unique_res"]?.try { |q| (q == "true" || q == "1").to_unsafe }

    begin
      video = get_video(id, region: region)
    rescue ex : NotFoundException
      haltf env, status_code: 404
    rescue ex
      haltf env, status_code: 403
    end

    if dashmpd = video.dash_manifest_url
      response = YT_POOL.client &.get(URI.parse(dashmpd).request_target)

      if response.status_code != 200
        haltf env, status_code: response.status_code
      end

      manifest = response.body

      manifest = manifest.gsub(/<BaseURL>[^<]+<\/BaseURL>/) do |baseurl|
        url = baseurl.lchop("<BaseURL>")
        url = url.rchop("</BaseURL>")

        if local
          uri = URI.parse(url)
          url = "#{HOST_URL}#{uri.request_target}host/#{uri.host}/"
        end

        "<BaseURL>#{url}</BaseURL>"
      end

      return manifest
    end

    # Transform URLs for proxying
    if local
      video.adaptive_fmts.each do |fmt|
        fmt.url = "#{HOST_URL}#{URI.parse(fmt.url).request_target}"
      end
    end

    audio_streams = video.audio_streams.sort_by(&.bitrate).reverse!
    video_streams = video.video_streams.sort_by { |fmt| {fmt.video_width, fmt.video_fps} }.reverse!

    # Build the manifest
    return XML.build(indent: "  ", encoding: "UTF-8") do |xml|
      xml.element("MPD", "xmlns": "urn:mpeg:dash:schema:mpd:2011",
        "profiles": "urn:mpeg:dash:profile:full:2011", minBufferTime: "PT1.5S", type: "static",
        mediaPresentationDuration: "PT#{video.length_seconds}S") do
        xml.element("Period") do
          i = 0

          {"audio/mp4"}.each do |mime_type|
            formats = audio_streams.select(&.mime_type.== mime_type)
            next if formats.empty?

            formats.each do |fmt|
              # OTF streams aren't supported yet (See https://github.com/TeamNewPipe/NewPipe/issues/2415)
              next if (fmt.index_range.nil? || fmt.init_range.nil?)

              # Different representations of the same audio should be groupped into one AdaptationSet.
              # However, most players don't support auto quality switching, so we have to trick them
              # into providing a quality selector.
              # See https://github.com/iv-org/invidious/issues/3074 for more details.
              xml.element("AdaptationSet", id: i, mimeType: mime_type, startWithSAP: 1, subsegmentAlignment: true, label: "#{(fmt.bitrate // 1000)} kbps") do
                xml.element("Role", schemeIdUri: "urn:mpeg:dash:role:2011", value: i == 0 ? "main" : "alternate")
                xml.element("Representation", id: fmt.itag, codecs: fmt.codecs, bandwidth: fmt.bitrate) do
                  xml.element("AudioChannelConfiguration", schemeIdUri: "urn:mpeg:dash:23003:3:audio_channel_configuration:2011", value: fmt.audio_channels)
                  xml.element("BaseURL") { xml.text fmt.url }
                  xml.element("SegmentBase", indexRange: fmt.index_range.to_s) do
                    xml.element("Initialization", range: fmt.init_range.to_s)
                  end
                end
              end

              i += 1
            end
          end

          potential_heights = {4320, 2160, 1440, 1080, 720, 480, 360, 240, 144}

          {"video/mp4"}.each do |mime_type|
            mime_streams = video_streams.select(&.mime_type.== mime_type)
            next if mime_streams.empty?

            heights = [] of Int32

            xml.element("AdaptationSet", id: i, mimeType: mime_type, startWithSAP: 1, subsegmentAlignment: true, scanType: "progressive") do
              mime_streams.each do |fmt|
                # OTF streams aren't supported yet (See https://github.com/TeamNewPipe/NewPipe/issues/2415)
                next if (fmt.index_range.nil? || fmt.init_range.nil?)

                # Resolutions reported by YouTube player (may not accurately reflect source)
                height = potential_heights.min_by { |x| (fmt.video_height.to_i32 - x).abs }
                next if unique_res && heights.includes? height
                heights << height

                xml.element("Representation", id: fmt.itag, codecs: fmt.codecs, width: fmt.video_width, height: height,
                  startWithSAP: "1", maxPlayoutRate: "1", bandwidth: fmt.bitrate, frameRate: fmt.video_fps) do
                  xml.element("BaseURL") { xml.text fmt.url }
                  xml.element("SegmentBase", indexRange: fmt.index_range.to_s) do
                    xml.element("Initialization", range: fmt.init_range.to_s)
                  end
                end
              end
            end

            i += 1
          end
        end
      end
    end
  end

  # /api/manifest/dash/id/videoplayback
  def self.get_dash_video_playback(env)
    env.response.headers.delete("Content-Type")
    env.response.headers["Access-Control-Allow-Origin"] = "*"
    env.redirect "/videoplayback?#{env.params.query}"
  end

  # /api/manifest/dash/id/videoplayback/*
  def self.get_dash_video_playback_greedy(env)
    env.response.headers.delete("Content-Type")
    env.response.headers["Access-Control-Allow-Origin"] = "*"
    env.redirect env.request.path.lchop("/api/manifest/dash/id")
  end

  # /api/manifest/dash/id/videoplayback && /api/manifest/dash/id/videoplayback/*
  def self.options_dash_video_playback(env)
    env.response.headers.delete("Content-Type")
    env.response.headers["Access-Control-Allow-Origin"] = "*"
    env.response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Range"
  end

  # /api/manifest/hls_playlist/*
  def self.get_hls_playlist(env)
    response = YT_POOL.client &.get(env.request.path)

    if response.status_code != 200
      haltf env, status_code: response.status_code
    end

    local = env.params.query["local"]?.try &.== "true"

    env.response.content_type = "application/x-mpegURL"
    env.response.headers.add("Access-Control-Allow-Origin", "*")

    manifest = response.body

    if local
      manifest = manifest.gsub(/^https:\/\/\w+---.{11}\.c\.youtube\.com[^\n]*/m) do |match|
        path = URI.parse(match).path

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

        raw_params = HTTP::Params.new(raw_params)
        if fvip = raw_params["hls_chunk_host"].match(/r(?<fvip>\d+)---/)
          raw_params["fvip"] = fvip["fvip"]
        end

        raw_params["local"] = "true"

        "#{HOST_URL}/videoplayback?#{raw_params}"
      end
    end

    manifest
  end

  # /api/manifest/hls_variant/*
  def self.get_hls_variant(env)
    response = YT_POOL.client &.get(env.request.path)

    if response.status_code != 200
      haltf env, status_code: response.status_code
    end

    local = env.params.query["local"]?.try &.== "true"

    env.response.content_type = "application/x-mpegURL"
    env.response.headers.add("Access-Control-Allow-Origin", "*")

    manifest = response.body

    if local
      manifest = manifest.gsub("https://www.youtube.com", HOST_URL)
      manifest = manifest.gsub("index.m3u8", "index.m3u8?local=true")
    end

    manifest
  end
end
