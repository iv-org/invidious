require "html"

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

      transcript = Invidious::Videos::Transcript.from_raw(
        YoutubeAPI.get_transcript(params),
        caption.language_code,
        caption.auto_generated
      )

      webvtt = transcript.to_vtt
    else
      # Timedtext API handling
      url = URI.parse("#{caption.base_url}&tlang=#{tlang}").request_target

      # Auto-generated captions often have cues that aren't aligned properly with the video,
      # as well as some other markup that makes it cumbersome, so we try to fix that here
      if caption.name.includes? "auto-generated"
        caption_xml = YT_POOL.client &.get(url).body

        settings_field = {
          "Kind"     => "captions",
          "Language" => "#{tlang || caption.language_code}",
        }

        if caption_xml.starts_with?("<?xml")
          webvtt = caption.timedtext_to_vtt(caption_xml, tlang)
        else
          caption_xml = XML.parse(caption_xml)

          webvtt = WebVTT.build(settings_field) do |builder|
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

              text = HTML.unescape(node.content)
              text = text.gsub(/<font color="#[a-fA-F0-9]{6}">/, "")
              text = text.gsub(/<\/font>/, "")
              if md = text.match(/(?<name>.*) : (?<text>.*)/)
                text = "<v #{md["name"]}>#{md["text"]}</v>"
              end

              builder.cue(start_time, end_time, text)
            end
          end
        end
      else
        uri = URI.parse(url)
        query_params = uri.query_params
        query_params["fmt"] = "vtt"
        uri.query_params = query_params
        webvtt = YT_POOL.client &.get(uri.request_target).body

        if webvtt.starts_with?("<?xml")
          webvtt = caption.timedtext_to_vtt(webvtt)
        else
          # Some captions have "align:[start/end]" and "position:[num]%"
          # attributes. Those are causing issues with VideoJS, which is unable
          # to properly align the captions on the video, so we remove them.
          #
          # See: https://github.com/iv-org/invidious/issues/2391
          webvtt = webvtt.gsub(/([0-9:.]{12} --> [0-9:.]{12}).+/, "\\1")
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

    width = env.params.query["width"]?.try &.to_i
    height = env.params.query["height"]?.try &.to_i

    if !width && !height
      response = JSON.build do |json|
        json.object do
          json.field "storyboards" do
            Invidious::JSONify::APIv1.storyboards(json, id, video.storyboards)
          end
        end
      end

      return response
    end

    env.response.content_type = "text/vtt"

    # Select a storyboard matching the user's provided width/height
    storyboard = video.storyboards.select { |x| x.width == width || x.height == height }
    haltf env, 404 if storyboard.empty?

    # Alias variable, to make the code below esaier to read
    sb = storyboard[0]

    # Some base URL segments that we'll use to craft the final URLs
    work_url = sb.proxied_url.dup
    template_path = sb.proxied_url.path

    # Initialize cue timing variables
    # NOTE: videojs-vtt-thumbnails gets lost when the cue times don't overlap
    # (i.e: if cue[n] end time is 1:06:25.000, cue[n+1] start time should be 1:06:25.000)
    time_delta = sb.interval.milliseconds
    start_time = 0.milliseconds
    end_time = time_delta

    # Build a VTT file for VideoJS-vtt plugin
    vtt_file = WebVTT.build do |vtt|
      sb.images_count.times do |i|
        # Replace the variable component part of the path
        work_url.path = template_path.sub("$M", i)

        sb.rows.times do |j|
          sb.columns.times do |k|
            # The URL fragment represents the offset of the thumbnail inside the storyboard image
            work_url.fragment = "xywh=#{sb.width * k},#{sb.height * j},#{sb.width - 2},#{sb.height}"

            vtt.cue(start_time, end_time, work_url.to_s)

            start_time += time_delta
            end_time += time_delta
          end
        end
      end
    end

    # videojs-vtt-thumbnails is not compliant to the VTT specification, it
    # doesn't unescape the HTML entities, so we have to do it here:
    # TODO: remove this when we migrate to VideoJS 8
    return HTML.unescape(vtt_file)
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
        index = CHARS_SAFE.index!(id[0]).to_s.rjust(2, '0')

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

  def self.clips(env)
    locale = env.get("preferences").as(Preferences).locale

    env.response.content_type = "application/json"

    clip_id = env.params.url["id"]
    region = env.params.query["region"]?
    proxy = {"1", "true"}.any? &.== env.params.query["local"]?

    response = YoutubeAPI.resolve_url("https://www.youtube.com/clip/#{clip_id}")
    return error_json(400, "Invalid clip ID") if response["error"]?

    video_id = response.dig?("endpoint", "watchEndpoint", "videoId").try &.as_s
    return error_json(400, "Invalid clip ID") if video_id.nil?

    start_time = nil
    end_time = nil
    clip_title = nil

    if params = response.dig?("endpoint", "watchEndpoint", "params").try &.as_s
      start_time, end_time, clip_title = parse_clip_parameters(params)
    end

    begin
      video = get_video(video_id, region: region)
    rescue ex : NotFoundException
      return error_json(404, ex)
    rescue ex
      return error_json(500, ex)
    end

    return JSON.build do |json|
      json.object do
        json.field "startTime", start_time
        json.field "endTime", end_time
        json.field "clipTitle", clip_title
        json.field "video" do
          Invidious::JSONify::APIv1.video(video, json, locale: locale, proxy: proxy)
        end
      end
    end
  end

  # Fetches transcripts from YouTube
  #
  # Use the `lang` and `autogen` query parameter to select which transcript to fetch
  # Request without any URL parameters to see all the available transcripts.
  def self.transcripts(env)
    env.response.content_type = "application/json"

    id = env.params.url["id"]
    lang = env.params.query["lang"]?
    label = env.params.query["label"]?
    auto_generated = env.params.query["autogen"]? ? true : false

    # Return all available transcript options when none is given
    if !label && !lang
      begin
        video = get_video(id)
      rescue ex : NotFoundException
        return error_json(404, ex)
      rescue ex
        return error_json(500, ex)
      end

      response = JSON.build do |json|
        # The amount of transcripts available to fetch is the
        # same as the amount of captions available.
        available_transcripts = video.captions

        json.object do
          json.field "transcripts" do
            json.array do
              available_transcripts.each do |transcript|
                json.object do
                  json.field "label", transcript.name
                  json.field "languageCode", transcript.language_code
                  json.field "autoGenerated", transcript.auto_generated

                  if transcript.auto_generated
                    json.field "url", "/api/v1/transcripts/#{id}?lang=#{URI.encode_www_form(transcript.language_code)}&autogen"
                  else
                    json.field "url", "/api/v1/transcripts/#{id}?lang=#{URI.encode_www_form(transcript.language_code)}"
                  end
                end
              end
            end
          end
        end
      end

      return response
    end

    # If lang is not given then we attempt to fetch
    # the transcript through the given label
    if lang.nil?
      begin
        video = get_video(id)
      rescue ex : NotFoundException
        return error_json(404, ex)
      rescue ex
        return error_json(500, ex)
      end

      target_transcript = video.captions.select(&.name.== label)
      if target_transcript.empty?
        return error_json(404, NotFoundException.new("Requested transcript does not exist"))
      else
        target_transcript = target_transcript[0]
        lang, auto_generated = target_transcript.language_code, target_transcript.auto_generated
      end
    end

    params = Invidious::Videos::Transcript.generate_param(id, lang, auto_generated)

    begin
      transcript = Invidious::Videos::Transcript.from_raw(
        YoutubeAPI.get_transcript(params), lang, auto_generated
      )
    rescue ex : NotFoundException
      return error_json(404, ex)
    rescue ex
      return error_json(500, ex)
    end

    return transcript.to_json
  end
end
