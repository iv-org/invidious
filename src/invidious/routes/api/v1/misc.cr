module Invidious::Routes::API::V1::Misc
  # Stats API endpoint for Invidious
  def self.stats(env)
    env.response.content_type = "application/json"

    if !CONFIG.statistics_enabled
      return {"software" => SOFTWARE}.to_json
    else
      return Invidious::Jobs::StatisticsRefreshJob::STATISTICS.to_json
    end
  end

  # APIv1 currently uses the same logic for both
  # user playlists and Invidious playlists. This means that we can't
  # reasonably split them yet. This should be addressed in APIv2
  def self.get_playlist(env : HTTP::Server::Context)
    env.response.content_type = "application/json"
    plid = env.params.url["plid"]

    offset = env.params.query["index"]?.try &.to_i?
    offset ||= env.params.query["page"]?.try &.to_i?.try { |page| (page - 1) * 100 }
    offset ||= 0

    video_id = env.params.query["continuation"]?

    format = env.params.query["format"]?
    format ||= "json"

    if plid.starts_with? "RD"
      return env.redirect "/api/v1/mixes/#{plid}"
    end

    begin
      playlist = get_playlist(plid)
    rescue ex : InfoException
      return error_json(404, ex)
    rescue ex
      return error_json(404, "Playlist does not exist.")
    end

    user = env.get?("user").try &.as(User)
    if !playlist || playlist.privacy.private? && playlist.author != user.try &.email
      return error_json(404, "Playlist does not exist.")
    end

    # includes into the playlist a maximum of 20 videos, before the offset
    if offset > 0
      lookback = offset < 50 ? offset : 50
      response = playlist.to_json(offset - lookback)
      json_response = JSON.parse(response)
    else
      #  Unless the continuation is really the offset 0, it becomes expensive.
      #  It happens when the offset is not set.
      #  First we find the actual offset, and then we lookback
      #  it shouldn't happen often though

      lookback = 0
      response = playlist.to_json(offset, video_id: video_id)
      json_response = JSON.parse(response)

      if json_response["videos"].as_a[0]["index"] != offset
        offset = json_response["videos"].as_a[0]["index"].as_i
        lookback = offset < 50 ? offset : 50
        response = playlist.to_json(offset - lookback)
        json_response = JSON.parse(response)
      end
    end

    if format == "html"
      playlist_html = template_playlist(json_response)
      index, next_video = json_response["videos"].as_a.skip(1 + lookback).select { |video| !video["author"].as_s.empty? }[0]?.try { |v| {v["index"], v["videoId"]} } || {nil, nil}

      response = {
        "playlistHtml" => playlist_html,
        "index"        => index,
        "nextVideo"    => next_video,
      }.to_json
    end

    response
  end

  def self.mixes(env)
    locale = env.get("preferences").as(Preferences).locale

    env.response.content_type = "application/json"

    rdid = env.params.url["rdid"]

    continuation = env.params.query["continuation"]?
    continuation ||= rdid.lchop("RD")[0, 11]

    format = env.params.query["format"]?
    format ||= "json"

    begin
      mix = fetch_mix(rdid, continuation, locale: locale)

      if !rdid.ends_with? continuation
        mix = fetch_mix(rdid, mix.videos[1].id)
        index = mix.videos.index(mix.videos.select { |video| video.id == continuation }[0]?)
      end

      mix.videos = mix.videos[index..-1]
    rescue ex
      return error_json(500, ex)
    end

    response = JSON.build do |json|
      json.object do
        json.field "title", mix.title
        json.field "mixId", mix.id

        json.field "videos" do
          json.array do
            mix.videos.each do |video|
              json.object do
                json.field "title", video.title
                json.field "videoId", video.id
                json.field "author", video.author

                json.field "authorId", video.ucid
                json.field "authorUrl", "/channel/#{video.ucid}"

                json.field "videoThumbnails" do
                  json.array do
                    Invidious::JSONify::APIv1.thumbnails(json, video.id)
                  end
                end

                json.field "index", video.index
                json.field "lengthSeconds", video.length_seconds
              end
            end
          end
        end
      end
    end

    if format == "html"
      response = JSON.parse(response)
      playlist_html = template_mix(response)
      next_video = response["videos"].as_a.select { |video| !video["author"].as_s.empty? }[0]?.try &.["videoId"]

      response = {
        "playlistHtml" => playlist_html,
        "nextVideo"    => next_video,
      }.to_json
    end

    response
  end

  # resolve channel and clip urls, return the UCID
  def self.resolve_url(env)
    env.response.content_type = "application/json"
    url = env.params.query["url"]?

    return error_json(400, "Missing URL to resolve") if !url

    begin
      resolved_url = YoutubeAPI.resolve_url(url.as(String))
      endpoint = resolved_url["endpoint"]
      pageType = endpoint.dig?("commandMetadata", "webCommandMetadata", "webPageType").try &.as_s || ""
      if resolved_ucid = endpoint.dig?("watchEndpoint", "videoId")
      elsif resolved_ucid = endpoint.dig?("browseEndpoint", "browseId")
      elsif pageType == "WEB_PAGE_TYPE_UNKNOWN"
        return error_json(400, "Unknown url")
      end
    rescue ex
      return error_json(500, ex)
    end
    JSON.build do |json|
      json.object do
        json.field "ucid", resolved_ucid.try &.as_s || ""
        json.field "pageType", pageType
      end
    end
  end
end
