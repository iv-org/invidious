module Invidious::Routes::API::V1::Videos
  def self.videos(env)
    locale = env.get("preferences").as(Preferences).locale

    env.response.content_type = "application/json"

    id = env.params.url["id"]
    region = env.params.query["region"]?
    proxy = {"1", "true"}.any? &.== env.params.query["local"]?

    begin
      video = get_video(id, region: region)
    rescue ex : NotFoundException
      return error_json(404, ex)
    rescue ex
      return error_json(500, ex)
    end

    return JSON.build do |json|
      Invidious::JSONify::APIv1.video(video, json, locale: locale, proxy: proxy)
    end
  end

  def self.captions(env)
    env.response.content_type = "application/json"

    id = env.params.url["id"]
    region = env.params.query["region"]? || env.params.body["region"]?

    if id.nil? || id.size != 11 || !id.matches?(/^[\w-]+$/)
      return error_json(400, "Invalid video ID")
    end

    # See https://github.com/ytdl-org/youtube-dl/blob/6ab30ff50bf6bd0585927cb73c7421bef184f87a/youtube_dl/extractor/youtube.py#L1354
    # It is possible to use `/api/timedtext?type=list&v=#{id}` and
    # `/api/timedtext?type=track&v=#{id}&lang=#{lang_code}` directly,
    # but this does not provide links for auto-generated captions.
    #
    # In future this should be investigated as an alternative, since it does not require
    # getting video info.

    begin
      video = get_video(id, region: region)
    rescue ex : NotFoundException
      haltf env, 404
    rescue ex
      haltf env, 500
    end

    captions = video.captions

    label = env.params.query["label"]?
    lang = env.params.query["lang"]?
    tlang = env.params.query["tlang"]?

    if !label && !lang
      response = JSON.build do |json|
        json.object do
          json.field "captions" do
            json.array do
              captions.each do |caption|
                json.object do
                  json.field "label", caption.name
                  json.field "languageCode", caption.language_code
                  json.field "url", "/api/v1/captions/#{id}?label=#{URI.encode_www_form(caption.name)}"
                end
              end
            end
          end
        end
      end

      return response
    end

    env.response.content_type = "text/vtt; charset=UTF-8"

    if lang
      caption = captions.select(&.language_code.== lang)
    else
      caption = captions.select(&.name.== label)
    end

    if caption.empty?
      haltf env, 404
    else
      caption = caption[0]
    end

    if CONFIG.use_innertube_for_captions
      params = Invidious::Videos::Transcript.generate_param(id, caption.language_code, caption.auto_generated)
      initial_data = YoutubeAPI.get_transcript(params)

      webvtt = Invidious::Videos::Transcript.convert_transcripts_to_vtt(initial_data, caption.language_code)
    else
      # Timedtext API handling
      url = URI.parse("#{caption.base_url}&tlang=#{tlang}").request_target

      # Auto-generated captions often have cues that aren't aligned properly with the video,
      # as well as some other markup that makes it cumbersome, so we try to fix that here
      if caption.name.includes? "auto-generated"
        caption_xml = YT_POOL.client &.get(url).body

        if caption_xml.starts_with?("<?xml")
          webvtt = caption.timedtext_to_vtt(caption_xml, tlang)
        else
          caption_xml = XML.parse(caption_xml)

          webvtt = String.build do |str|
            str << <<-END_VTT
            WEBVTT
            Kind: captions
            Language: #{tlang || caption.language_code}


            END_VTT

            caption_nodes = caption_xml.xpath_nodes("//transcript/text")
            caption_nodes.each_with_index do |node, i|
              start_time = node["start"].to_f.seconds
              duration = node["dur"]?.try &.to_f.seconds
              duration ||= start_time

              if caption_nodes.size > i + 1
                end_time = caption_nodes[i + 1]["start"].to_f.seconds
              else
                end_time = start_time + duration
              end

              start_time = "#{start_time.hours.to_s.rjust(2, '0')}:#{start_time.minutes.to_s.rjust(2, '0')}:#{start_time.seconds.to_s.rjust(2, '0')}.#{start_time.milliseconds.to_s.rjust(3, '0')}"
              end_time = "#{end_time.hours.to_s.rjust(2, '0')}:#{end_time.minutes.to_s.rjust(2, '0')}:#{end_time.seconds.to_s.rjust(2, '0')}.#{end_time.milliseconds.to_s.rjust(3, '0')}"

              text = HTML.unescape(node.content)
              text = text.gsub(/<font color="#[a-fA-F0-9]{6}">/, "")
              text = text.gsub(/<\/font>/, "")
              if md = text.match(/(?<name>.*) : (?<text>.*)/)
                text = "<v #{md["name"]}>#{md["text"]}</v>"
              end

              str << <<-END_CUE
              #{start_time} --> #{end_time}
              #{text}


              END_CUE
            end
          end
        end
      else
        # Some captions have "align:[start/end]" and "position:[num]%"
        # attributes. Those are causing issues with VideoJS, which is unable
        # to properly align the captions on the video, so we remove them.
        #
        # See: https://github.com/iv-org/invidious/issues/2391
        webvtt = YT_POOL.client &.get("#{url}&format=vtt").body
        if webvtt.starts_with?("<?xml")
          webvtt = caption.timedtext_to_vtt(webvtt)
        else
          webvtt = YT_POOL.client &.get("#{url}&format=vtt").body
            .gsub(/([0-9:.]{12} --> [0-9:.]{12}).+/, "\\1")
        end
      end
    end

    if title = env.params.query["title"]?
      # https://blog.fastmail.com/2011/06/24/download-non-english-filenames/
      env.response.headers["Content-Disposition"] = "attachment; filename=\"#{URI.encode_www_form(title)}\"; filename*=UTF-8''#{URI.encode_www_form(title)}"
    end

    webvtt
  end

  # Fetches YouTube storyboards
  #
  # Which are sprites containing x * y preview
  # thumbnails for individual scenes in a video.
  # See https://support.jwplayer.com/articles/how-to-add-preview-thumbnails
  def self.storyboards(env)
    env.response.content_type = "application/json"

    id = env.params.url["id"]
    region = env.params.query["region"]?

    begin
      video = get_video(id, region: region)
    rescue ex : NotFoundException
      haltf env, 404
    rescue ex
      haltf env, 500
    end

    storyboards = video.storyboards
    width = env.params.query["width"]?
    height = env.params.query["height"]?

    if !width && !height
      response = JSON.build do |json|
        json.object do
          json.field "storyboards" do
            Invidious::JSONify::APIv1.storyboards(json, id, storyboards)
          end
        end
      end

      return response
    end

    env.response.content_type = "text/vtt"

    storyboard = storyboards.select { |sb| width == "#{sb[:width]}" || height == "#{sb[:height]}" }

    if storyboard.empty?
      haltf env, 404
    else
      storyboard = storyboard[0]
    end

    String.build do |str|
      str << <<-END_VTT
      WEBVTT
      END_VTT

      start_time = 0.milliseconds
      end_time = storyboard[:interval].milliseconds

      storyboard[:storyboard_count].times do |i|
        url = storyboard[:url]
        authority = /(i\d?).ytimg.com/.match(url).not_nil![1]?
        url = url.gsub("$M", i).gsub(%r(https://i\d?.ytimg.com/sb/), "")
        url = "#{HOST_URL}/sb/#{authority}/#{url}"

        storyboard[:storyboard_height].times do |j|
          storyboard[:storyboard_width].times do |k|
            str << <<-END_CUE
            #{start_time}.000 --> #{end_time}.000
            #{url}#xywh=#{storyboard[:width] * k},#{storyboard[:height] * j},#{storyboard[:width] - 2},#{storyboard[:height]}


            END_CUE

            start_time += storyboard[:interval].milliseconds
            end_time += storyboard[:interval].milliseconds
          end
        end
      end
    end
  end

  def self.annotations(env)
    env.response.content_type = "text/xml"

    id = env.params.url["id"]
    source = env.params.query["source"]?
    source ||= "archive"

    if !id.match(/[a-zA-Z0-9_-]{11}/)
      haltf env, 400
    end

    annotations = ""

    case source
    when "archive"
      if CONFIG.cache_annotations && (cached_annotation = Invidious::Database::Annotations.select(id))
        annotations = cached_annotation.annotations
      else
        index = CHARS_SAFE.index(id[0]).not_nil!.to_s.rjust(2, '0')

        # IA doesn't handle leading hyphens,
        # so we use https://archive.org/details/youtubeannotations_64
        if index == "62"
          index = "64"
          id = id.sub(/^-/, 'A')
        end

        file = URI.encode_www_form("#{id[0, 3]}/#{id}.xml")

        location = make_client(ARCHIVE_URL, &.get("/download/youtubeannotations_#{index}/#{id[0, 2]}.tar/#{file}"))

        if !location.headers["Location"]?
          env.response.status_code = location.status_code
        end

        response = make_client(URI.parse(location.headers["Location"]), &.get(location.headers["Location"]))

        if response.body.empty?
          haltf env, 404
        end

        if response.status_code != 200
          haltf env, response.status_code
        end

        annotations = response.body

        cache_annotation(id, annotations)
      end
    else # "youtube"
      response = YT_POOL.client &.get("/annotations_invideo?video_id=#{id}")

      if response.status_code != 200
        haltf env, response.status_code
      end

      annotations = response.body
    end

    etag = sha256(annotations)[0, 16]
    if env.request.headers["If-None-Match"]?.try &.== etag
      haltf env, 304
    else
      env.response.headers["ETag"] = etag
      annotations
    end
  end

  def self.comments(env)
    locale = env.get("preferences").as(Preferences).locale
    region = env.params.query["region"]?

    env.response.content_type = "application/json"

    id = env.params.url["id"]

    source = env.params.query["source"]?
    source ||= "youtube"

    thin_mode = env.params.query["thin_mode"]?
    thin_mode = thin_mode == "true"

    format = env.params.query["format"]?
    format ||= "json"

    action = env.params.query["action"]?
    action ||= "action_get_comments"

    continuation = env.params.query["continuation"]?
    sort_by = env.params.query["sort_by"]?.try &.downcase

    if source == "youtube"
      sort_by ||= "top"

      begin
        comments = Comments.fetch_youtube(id, continuation, format, locale, thin_mode, region, sort_by: sort_by)
      rescue ex : NotFoundException
        return error_json(404, ex)
      rescue ex
        return error_json(500, ex)
      end

      return comments
    elsif source == "reddit"
      sort_by ||= "confidence"

      begin
        comments, reddit_thread = Comments.fetch_reddit(id, sort_by: sort_by)
      rescue ex
        comments = nil
        reddit_thread = nil
      end

      if !reddit_thread || !comments
        return error_json(404, "No reddit threads found")
      end

      if format == "json"
        reddit_thread = JSON.parse(reddit_thread.to_json).as_h
        reddit_thread["comments"] = JSON.parse(comments.to_json)

        return reddit_thread.to_json
      else
        content_html = Frontend::Comments.template_reddit(comments, locale)
        content_html = Comments.fill_links(content_html, "https", "www.reddit.com")
        content_html = Comments.replace_links(content_html)
        response = {
          "title"       => reddit_thread.title,
          "permalink"   => reddit_thread.permalink,
          "contentHtml" => content_html,
        }

        return response.to_json
      end
    end
  end
end
