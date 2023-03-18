require "json"

module Invidious::JSONify::APIv1
  extend self

  def video(video : Video, json : JSON::Builder, *, locale : String?, proxy : Bool = false)
    json.object do
      json.field "type", video.video_type

      json.field "title", video.title
      json.field "videoId", video.id

      json.field "error", video.info["reason"] if video.info["reason"]?

      json.field "videoThumbnails" do
        self.thumbnails(json, video.id)
      end
      json.field "storyboards" do
        self.storyboards(json, video.id, video.storyboards)
      end

      json.field "description", video.description
      json.field "descriptionHtml", video.description_html
      json.field "published", video.published.to_unix
      json.field "publishedText", translate(locale, "`x` ago", recode_date(video.published, locale))
      json.field "keywords", video.keywords

      json.field "viewCount", video.views
      json.field "likeCount", video.likes
      json.field "dislikeCount", 0_i64

      json.field "paid", video.paid
      json.field "premium", video.premium
      json.field "isFamilyFriendly", video.is_family_friendly
      json.field "allowedRegions", video.allowed_regions
      json.field "genre", video.genre
      json.field "genreUrl", video.genre_url

      json.field "author", video.author
      json.field "authorId", video.ucid
      json.field "authorUrl", "/channel/#{video.ucid}"

      json.field "authorThumbnails" do
        json.array do
          qualities = {32, 48, 76, 100, 176, 512}

          qualities.each do |quality|
            json.object do
              json.field "url", video.author_thumbnail.gsub(/=s\d+/, "=s#{quality}")
              json.field "width", quality
              json.field "height", quality
            end
          end
        end
      end

      json.field "subCountText", video.sub_count_text

      json.field "lengthSeconds", video.length_seconds
      json.field "allowRatings", video.allow_ratings
      json.field "rating", 0_i64
      json.field "isListed", video.is_listed
      json.field "liveNow", video.live_now
      json.field "isUpcoming", video.is_upcoming

      if video.premiere_timestamp
        json.field "premiereTimestamp", video.premiere_timestamp.try &.to_unix
      end

      if hlsvp = video.hls_manifest_url
        hlsvp = hlsvp.gsub("https://manifest.googlevideo.com", HOST_URL)
        json.field "hlsUrl", hlsvp
      end

      json.field "dashUrl", "#{HOST_URL}/api/manifest/dash/id/#{video.id}"

      json.field "adaptiveFormats" do
        json.array do
          video.adaptive_fmts.each do |fmt|
            json.object do
              # Only available on regular videos, not livestreams/OTF streams
              if init_range = fmt["initRange"]?
                json.field "init", "#{init_range["start"]}-#{init_range["end"]}"
              end
              if index_range = fmt["indexRange"]?
                json.field "index", "#{index_range["start"]}-#{index_range["end"]}"
              end

              # Not available on MPEG-4 Timed Text (`text/mp4`) streams (livestreams only)
              json.field "bitrate", fmt["bitrate"].as_i.to_s if fmt["bitrate"]?

              if proxy
                json.field "url", Invidious::HttpServer::Utils.proxy_video_url(
                  fmt["url"].to_s, absolute: true
                )
              else
                json.field "url", fmt["url"]
              end

              json.field "itag", fmt["itag"].as_i.to_s
              json.field "type", fmt["mimeType"]
              json.field "clen", fmt["contentLength"]? || "-1"

              # Last modified is a unix timestamp with µS, with the dot omitted.
              # E.g: 1638056732(.)141582
              #
              # On livestreams, it's not present, so always fall back to the
              # current unix timestamp (up to mS precision) for compatibility.
              last_modified = fmt["lastModified"]?
              last_modified ||= "#{Time.utc.to_unix_ms.to_s}000"
              json.field "lmt", last_modified

              json.field "projectionType", fmt["projectionType"]

              if fmt_info = Invidious::Videos::Formats.itag_to_metadata?(fmt["itag"])
                fps = fmt_info["fps"]?.try &.to_i || fmt["fps"]?.try &.as_i || 30
                json.field "fps", fps
                json.field "container", fmt_info["ext"]
                json.field "encoding", fmt_info["vcodec"]? || fmt_info["acodec"]

                if fmt_info["height"]?
                  json.field "resolution", "#{fmt_info["height"]}p"

                  quality_label = "#{fmt_info["height"]}p"
                  if fps > 30
                    quality_label += "60"
                  end
                  json.field "qualityLabel", quality_label

                  if fmt_info["width"]?
                    json.field "size", "#{fmt_info["width"]}x#{fmt_info["height"]}"
                  end
                end
              end

              # Livestream chunk infos
              json.field "targetDurationSec", fmt["targetDurationSec"].as_i if fmt.has_key?("targetDurationSec")
              json.field "maxDvrDurationSec", fmt["maxDvrDurationSec"].as_i if fmt.has_key?("maxDvrDurationSec")

              # Audio-related data
              json.field "audioQuality", fmt["audioQuality"] if fmt.has_key?("audioQuality")
              json.field "audioSampleRate", fmt["audioSampleRate"].as_s.to_i if fmt.has_key?("audioSampleRate")
              json.field "audioChannels", fmt["audioChannels"] if fmt.has_key?("audioChannels")

              # Extra misc stuff
              json.field "colorInfo", fmt["colorInfo"] if fmt.has_key?("colorInfo")
              json.field "captionTrack", fmt["captionTrack"] if fmt.has_key?("captionTrack")
            end
          end
        end
      end

      json.field "formatStreams" do
        json.array do
          video.fmt_stream.each do |fmt|
            json.object do
              json.field "url", fmt["url"]
              json.field "itag", fmt["itag"].as_i.to_s
              json.field "type", fmt["mimeType"]
              json.field "quality", fmt["quality"]

              fmt_info = Invidious::Videos::Formats.itag_to_metadata?(fmt["itag"])
              if fmt_info
                fps = fmt_info["fps"]?.try &.to_i || fmt["fps"]?.try &.as_i || 30
                json.field "fps", fps
                json.field "container", fmt_info["ext"]
                json.field "encoding", fmt_info["vcodec"]? || fmt_info["acodec"]

                if fmt_info["height"]?
                  json.field "resolution", "#{fmt_info["height"]}p"

                  quality_label = "#{fmt_info["height"]}p"
                  if fps > 30
                    quality_label += "60"
                  end
                  json.field "qualityLabel", quality_label

                  if fmt_info["width"]?
                    json.field "size", "#{fmt_info["width"]}x#{fmt_info["height"]}"
                  end
                end
              end
            end
          end
        end
      end

      json.field "captions" do
        json.array do
          video.captions.each do |caption|
            json.object do
              json.field "label", caption.name
              json.field "language_code", caption.language_code
              json.field "url", "/api/v1/captions/#{video.id}?label=#{URI.encode_www_form(caption.name)}"
            end
          end
        end
      end

      if !video.music.empty?
        json.field "musicTracks" do
          json.array do
            video.music.each do |music|
              json.object do
                json.field "song", music.song
                json.field "artist", music.artist
                json.field "album", music.album
                json.field "license", music.license
              end
            end
          end
        end
      end

      json.field "recommendedVideos" do
        json.array do
          video.related_videos.each do |rv|
            if rv["id"]?
              json.object do
                json.field "videoId", rv["id"]
                json.field "title", rv["title"]
                json.field "videoThumbnails" do
                  self.thumbnails(json, rv["id"])
                end

                json.field "author", rv["author"]
                json.field "authorUrl", "/channel/#{rv["ucid"]?}"
                json.field "authorId", rv["ucid"]?
                if rv["author_thumbnail"]?
                  json.field "authorThumbnails" do
                    json.array do
                      qualities = {32, 48, 76, 100, 176, 512}

                      qualities.each do |quality|
                        json.object do
                          json.field "url", rv["author_thumbnail"].gsub(/s\d+-/, "s#{quality}-")
                          json.field "width", quality
                          json.field "height", quality
                        end
                      end
                    end
                  end
                end

                json.field "lengthSeconds", rv["length_seconds"]?.try &.to_i
                json.field "viewCountText", rv["short_view_count"]?
                json.field "viewCount", rv["view_count"]?.try &.empty? ? nil : rv["view_count"].to_i64
              end
            end
          end
        end
      end
    end
  end

  def storyboards(json, id, storyboards)
    json.array do
      storyboards.each do |storyboard|
        json.object do
          json.field "url", "/api/v1/storyboards/#{id}?width=#{storyboard[:width]}&height=#{storyboard[:height]}"
          json.field "templateUrl", storyboard[:url]
          json.field "width", storyboard[:width]
          json.field "height", storyboard[:height]
          json.field "count", storyboard[:count]
          json.field "interval", storyboard[:interval]
          json.field "storyboardWidth", storyboard[:storyboard_width]
          json.field "storyboardHeight", storyboard[:storyboard_height]
          json.field "storyboardCount", storyboard[:storyboard_count]
        end
      end
    end
  end
end
