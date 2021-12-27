# TODO: Add "sort_by"
def fetch_channel_community(ucid, continuation, locale, format, thin_mode)
  response = YT_POOL.client &.get("/channel/#{ucid}/community?gl=US&hl=en")
  if response.status_code != 200
    response = YT_POOL.client &.get("/user/#{ucid}/community?gl=US&hl=en")
  end

  if response.status_code != 200
    raise InfoException.new("This channel does not exist.")
  end

  ucid = response.body.match(/https:\/\/www.youtube.com\/channel\/(?<ucid>UC[a-zA-Z0-9_-]{22})/).not_nil!["ucid"]

  if !continuation || continuation.empty?
    initial_data = extract_initial_data(response.body)
    body = initial_data["contents"]?.try &.["twoColumnBrowseResultsRenderer"]["tabs"].as_a.select { |tab| tab["tabRenderer"]?.try &.["selected"].as_bool.== true }[0]?

    if !body
      raise InfoException.new("Could not extract community tab.")
    end

    body = body["tabRenderer"]["content"]["sectionListRenderer"]["contents"][0]["itemSectionRenderer"]
  else
    continuation = produce_channel_community_continuation(ucid, continuation)

    headers = HTTP::Headers.new
    headers["cookie"] = response.cookies.add_request_headers(headers)["cookie"]

    session_token = response.body.match(/"XSRF_TOKEN":"(?<session_token>[^"]+)"/).try &.["session_token"]? || ""
    post_req = {
      session_token: session_token,
    }

    response = YT_POOL.client &.post("/comment_service_ajax?action_get_comments=1&ctoken=#{continuation}&continuation=#{continuation}&hl=en&gl=US", headers, form: post_req)
    body = JSON.parse(response.body)

    body = body["response"]["continuationContents"]["itemSectionContinuation"]? ||
           body["response"]["continuationContents"]["backstageCommentsContinuation"]?

    if !body
      raise InfoException.new("Could not extract continuation.")
    end
  end

  continuation = body["continuations"]?.try &.[0]["nextContinuationData"]["continuation"].as_s
  posts = body["contents"].as_a

  if message = posts[0]["messageRenderer"]?
    error_message = (message["text"]["simpleText"]? ||
                     message["text"]["runs"]?.try &.[0]?.try &.["text"]?)
      .try &.as_s || ""
    raise InfoException.new(error_message)
  end

  response = JSON.build do |json|
    json.object do
      json.field "authorId", ucid
      json.field "comments" do
        json.array do
          posts.each do |post|
            comments = post["backstagePostThreadRenderer"]?.try &.["comments"]? ||
                       post["backstageCommentsContinuation"]?

            post = post["backstagePostThreadRenderer"]?.try &.["post"]["backstagePostRenderer"]? ||
                   post["commentThreadRenderer"]?.try &.["comment"]["commentRenderer"]?

            next if !post

            content_html = post["contentText"]?.try { |t| parse_content(t) } || ""
            author = post["authorText"]?.try &.["simpleText"]? || ""

            json.object do
              json.field "author", author
              json.field "authorThumbnails" do
                json.array do
                  qualities = {32, 48, 76, 100, 176, 512}
                  author_thumbnail = post["authorThumbnail"]["thumbnails"].as_a[0]["url"].as_s

                  qualities.each do |quality|
                    json.object do
                      json.field "url", author_thumbnail.gsub(/s\d+-/, "s#{quality}-")
                      json.field "width", quality
                      json.field "height", quality
                    end
                  end
                end
              end

              if post["authorEndpoint"]?
                json.field "authorId", post["authorEndpoint"]["browseEndpoint"]["browseId"]
                json.field "authorUrl", post["authorEndpoint"]["commandMetadata"]["webCommandMetadata"]["url"].as_s
              else
                json.field "authorId", ""
                json.field "authorUrl", ""
              end

              published_text = post["publishedTimeText"]["runs"][0]["text"].as_s
              published = decode_date(published_text.rchop(" (edited)"))

              if published_text.includes?(" (edited)")
                json.field "isEdited", true
              else
                json.field "isEdited", false
              end

              like_count = post["actionButtons"]["commentActionButtonsRenderer"]["likeButton"]["toggleButtonRenderer"]["accessibilityData"]["accessibilityData"]["label"]
                .try &.as_s.gsub(/\D/, "").to_i? || 0

              json.field "content", html_to_content(content_html)
              json.field "contentHtml", content_html

              json.field "published", published.to_unix
              json.field "publishedText", translate(locale, "`x` ago", recode_date(published, locale))

              json.field "likeCount", like_count
              json.field "commentId", post["postId"]? || post["commentId"]? || ""
              json.field "authorIsChannelOwner", post["authorEndpoint"]["browseEndpoint"]["browseId"] == ucid

              if attachment = post["backstageAttachment"]?
                json.field "attachment" do
                  json.object do
                    case attachment.as_h
                    when .has_key?("videoRenderer")
                      attachment = attachment["videoRenderer"]
                      json.field "type", "video"

                      if !attachment["videoId"]?
                        error_message = (attachment["title"]["simpleText"]? ||
                                         attachment["title"]["runs"]?.try &.[0]?.try &.["text"]?)

                        json.field "error", error_message
                      else
                        video_id = attachment["videoId"].as_s

                        video_title = attachment["title"]["simpleText"]? || attachment["title"]["runs"]?.try &.[0]?.try &.["text"]?
                        json.field "title", video_title
                        json.field "videoId", video_id
                        json.field "videoThumbnails" do
                          generate_thumbnails(json, video_id)
                        end

                        json.field "lengthSeconds", decode_length_seconds(attachment["lengthText"]["simpleText"].as_s)

                        author_info = attachment["ownerText"]["runs"][0].as_h

                        json.field "author", author_info["text"].as_s
                        json.field "authorId", author_info["navigationEndpoint"]["browseEndpoint"]["browseId"]
                        json.field "authorUrl", author_info["navigationEndpoint"]["commandMetadata"]["webCommandMetadata"]["url"]

                        # TODO: json.field "authorThumbnails", "channelThumbnailSupportedRenderers"
                        # TODO: json.field "authorVerified", "ownerBadges"

                        published = decode_date(attachment["publishedTimeText"]["simpleText"].as_s)

                        json.field "published", published.to_unix
                        json.field "publishedText", translate(locale, "`x` ago", recode_date(published, locale))

                        view_count = attachment["viewCountText"]?.try &.["simpleText"].as_s.gsub(/\D/, "").to_i64? || 0_i64

                        json.field "viewCount", view_count
                        json.field "viewCountText", translate_count(locale, "generic_views_count", view_count, NumberFormatting::Short)
                      end
                    when .has_key?("backstageImageRenderer")
                      attachment = attachment["backstageImageRenderer"]
                      json.field "type", "image"

                      json.field "imageThumbnails" do
                        json.array do
                          thumbnail = attachment["image"]["thumbnails"][0].as_h
                          width = thumbnail["width"].as_i
                          height = thumbnail["height"].as_i
                          aspect_ratio = (width.to_f / height.to_f)
                          url = thumbnail["url"].as_s.gsub(/=w\d+-h\d+(-p)?(-nd)?(-df)?(-rwa)?/, "=s640")

                          qualities = {320, 560, 640, 1280, 2000}

                          qualities.each do |quality|
                            json.object do
                              json.field "url", url.gsub(/=s\d+/, "=s#{quality}")
                              json.field "width", quality
                              json.field "height", (quality / aspect_ratio).ceil.to_i
                            end
                          end
                        end
                      end
                      # TODO
                      # when .has_key?("pollRenderer")
                      #   attachment = attachment["pollRenderer"]
                      #   json.field "type", "poll"
                    else
                      json.field "type", "unknown"
                      json.field "error", "Unrecognized attachment type."
                    end
                  end
                end
              end

              if comments && (reply_count = (comments["backstageCommentsRenderer"]["moreText"]["simpleText"]? ||
                                             comments["backstageCommentsRenderer"]["moreText"]["runs"]?.try &.[0]?.try &.["text"]?)
                   .try &.as_s.gsub(/\D/, "").to_i?)
                continuation = comments["backstageCommentsRenderer"]["continuations"]?.try &.as_a[0]["nextContinuationData"]["continuation"].as_s
                continuation ||= ""

                json.field "replies" do
                  json.object do
                    json.field "replyCount", reply_count
                    json.field "continuation", extract_channel_community_cursor(continuation)
                  end
                end
              end
            end
          end
        end
      end

      if body["continuations"]?
        continuation = body["continuations"][0]["nextContinuationData"]["continuation"].as_s
        json.field "continuation", extract_channel_community_cursor(continuation)
      end
    end
  end

  if format == "html"
    response = JSON.parse(response)
    content_html = template_youtube_comments(response, locale, thin_mode)

    response = JSON.build do |json|
      json.object do
        json.field "contentHtml", content_html
      end
    end
  end

  return response
end

def produce_channel_community_continuation(ucid, cursor)
  object = {
    "80226972:embedded" => {
      "2:string" => ucid,
      "3:string" => cursor || "",
    },
  }

  continuation = object.try { |i| Protodec::Any.cast_json(i) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return continuation
end

def extract_channel_community_cursor(continuation)
  object = URI.decode_www_form(continuation)
    .try { |i| Base64.decode(i) }
    .try { |i| IO::Memory.new(i) }
    .try { |i| Protodec::Any.parse(i) }
    .try(&.["80226972:0:embedded"]["3:1:base64"].as_h)

  if object["53:2:embedded"]?.try &.["3:0:embedded"]?
    object["53:2:embedded"]["3:0:embedded"]["2:0:string"] = object["53:2:embedded"]["3:0:embedded"]
      .try(&.["2:0:base64"].as_h)
      .try { |i| Protodec::Any.cast_json(i) }
      .try { |i| Protodec::Any.from_json(i) }
      .try { |i| Base64.urlsafe_encode(i, padding: false) }

    object["53:2:embedded"]["3:0:embedded"].as_h.delete("2:0:base64")
  end

  cursor = Protodec::Any.cast_json(object)
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }

  cursor
end
