private IMAGE_QUALITIES = {320, 560, 640, 1280, 2000}

# TODO: Add "sort_by"
def fetch_channel_community(ucid, cursor, locale, format, thin_mode)
  if cursor.nil?
    # Egljb21tdW5pdHk%3D is the protobuf object to load "community"
    initial_data = YoutubeAPI.browse(ucid, params: "Egljb21tdW5pdHk%3D")

    items = [] of JSON::Any
    extract_items(initial_data) do |item|
      items << item
    end
  else
    continuation = produce_channel_community_continuation(ucid, cursor)
    initial_data = YoutubeAPI.browse(continuation: continuation)

    container = initial_data.dig?("continuationContents", "itemSectionContinuation", "contents")

    raise InfoException.new("Can't extract community data") if container.nil?

    items = container.as_a
  end

  return extract_channel_community(items, ucid: ucid, locale: locale, format: format, thin_mode: thin_mode)
end

def fetch_channel_community_post(ucid, post_id, locale, format, thin_mode)
  object = {
    "2:string"    => "community",
    "25:embedded" => {
      "22:string" => post_id.to_s,
    },
    "45:embedded" => {
      "2:varint" => 1_i64,
      "3:varint" => 1_i64,
    },
  }
  params = object.try { |i| Protodec::Any.cast_json(i) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  initial_data = YoutubeAPI.browse(ucid, params: params)

  items = [] of JSON::Any
  extract_items(initial_data) do |item|
    items << item
  end

  return extract_channel_community(items, ucid: ucid, locale: locale, format: format, thin_mode: thin_mode, is_single_post: true)
end

def extract_channel_community(items, *, ucid, locale, format, thin_mode, is_single_post : Bool = false)
  if message = items[0]["messageRenderer"]?
    error_message = (message["text"]["simpleText"]? ||
                     message["text"]["runs"]?.try &.[0]?.try &.["text"]?)
      .try &.as_s || ""
    if error_message == "This channel does not exist."
      raise NotFoundException.new(error_message)
    else
      raise InfoException.new(error_message)
    end
  end

  response = JSON.build do |json|
    json.object do
      json.field "authorId", ucid
      if is_single_post
        json.field "singlePost", true
      end
      json.field "comments" do
        json.array do
          items.each do |post|
            comments = post["backstagePostThreadRenderer"]?.try &.["comments"]? ||
                       post["backstageCommentsContinuation"]?

            post = post["backstagePostThreadRenderer"]?.try &.["post"]["backstagePostRenderer"]? ||
                   post["commentThreadRenderer"]?.try &.["comment"]["commentRenderer"]?

            next if !post

            content_html = post["contentText"]?.try { |t| parse_content(t) } || ""
            author = post["authorText"]["runs"]?.try &.[0]?.try &.["text"]? || ""

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

              reply_count = short_text_to_number(post.dig?("actionButtons", "commentActionButtonsRenderer", "replyButton", "buttonRenderer", "text", "simpleText").try &.as_s || "0")

              json.field "content", html_to_content(content_html)
              json.field "contentHtml", content_html

              json.field "published", published.to_unix
              json.field "publishedText", translate(locale, "`x` ago", recode_date(published, locale))

              json.field "likeCount", like_count
              json.field "replyCount", reply_count
              json.field "commentId", post["postId"]? || post["commentId"]? || ""
              json.field "authorIsChannelOwner", post["authorEndpoint"]["browseEndpoint"]["browseId"] == ucid

              if attachment = post["backstageAttachment"]?
                json.field "attachment" do
                  case attachment.as_h
                  when .has_key?("videoRenderer")
                    parse_item(attachment)
                      .as(SearchVideo)
                      .to_json(locale, json)
                  when .has_key?("backstageImageRenderer")
                    json.object do
                      attachment = attachment["backstageImageRenderer"]
                      json.field "type", "image"

                      json.field "imageThumbnails" do
                        json.array do
                          thumbnail = attachment["image"]["thumbnails"][0].as_h
                          width = thumbnail["width"].as_i
                          height = thumbnail["height"].as_i
                          aspect_ratio = (width.to_f / height.to_f)
                          url = thumbnail["url"].as_s.gsub(/=w\d+-h\d+(-p)?(-nd)?(-df)?(-rwa)?/, "=s640")

                          IMAGE_QUALITIES.each do |quality|
                            json.object do
                              json.field "url", url.gsub(/=s\d+/, "=s#{quality}")
                              json.field "width", quality
                              json.field "height", (quality / aspect_ratio).ceil.to_i
                            end
                          end
                        end
                      end
                    end
                  when .has_key?("pollRenderer")
                    json.object do
                      attachment = attachment["pollRenderer"]
                      json.field "type", "poll"
                      json.field "totalVotes", short_text_to_number(attachment["totalVotes"]["simpleText"].as_s.split(" ")[0])
                      json.field "choices" do
                        json.array do
                          attachment["choices"].as_a.each do |choice|
                            json.object do
                              json.field "text", choice.dig("text", "runs", 0, "text").as_s
                              # A choice can have an image associated with it.
                              # Ex post: https://www.youtube.com/post/UgkxD4XavXUD4NQiddJXXdohbwOwcVqrH9Re
                              if choice["image"]?
                                thumbnail = choice["image"]["thumbnails"][0].as_h
                                width = thumbnail["width"].as_i
                                height = thumbnail["height"].as_i
                                aspect_ratio = (width.to_f / height.to_f)
                                url = thumbnail["url"].as_s.gsub(/=w\d+-h\d+(-p)?(-nd)?(-df)?(-rwa)?/, "=s640")
                                json.field "image" do
                                  json.array do
                                    IMAGE_QUALITIES.each do |quality|
                                      json.object do
                                        json.field "url", url.gsub(/=s\d+/, "=s#{quality}")
                                        json.field "width", quality
                                        json.field "height", (quality / aspect_ratio).ceil.to_i
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  when .has_key?("postMultiImageRenderer")
                    json.object do
                      attachment = attachment["postMultiImageRenderer"]
                      json.field "type", "multiImage"
                      json.field "images" do
                        json.array do
                          attachment["images"].as_a.each do |image|
                            json.array do
                              thumbnail = image["backstageImageRenderer"]["image"]["thumbnails"][0].as_h
                              width = thumbnail["width"].as_i
                              height = thumbnail["height"].as_i
                              aspect_ratio = (width.to_f / height.to_f)
                              url = thumbnail["url"].as_s.gsub(/=w\d+-h\d+(-p)?(-nd)?(-df)?(-rwa)?/, "=s640")

                              IMAGE_QUALITIES.each do |quality|
                                json.object do
                                  json.field "url", url.gsub(/=s\d+/, "=s#{quality}")
                                  json.field "width", quality
                                  json.field "height", (quality / aspect_ratio).ceil.to_i
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  when .has_key?("playlistRenderer")
                    parse_item(attachment)
                      .as(SearchPlaylist)
                      .to_json(locale, json)
                  when .has_key?("quizRenderer")
                    json.object do
                      attachment = attachment["quizRenderer"]
                      json.field "type", "quiz"
                      json.field "totalVotes", short_text_to_number(attachment["totalVotes"]["simpleText"].as_s.split(" ")[0])
                      json.field "choices" do
                        json.array do
                          attachment["choices"].as_a.each do |choice|
                            json.object do
                              json.field "text", choice.dig("text", "runs", 0, "text").as_s
                              json.field "isCorrect", choice["isCorrect"].as_bool
                            end
                          end
                        end
                      end
                    end
                  else
                    json.object do
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
      if !is_single_post
        if cont = items.dig?(-1, "continuationItemRenderer", "continuationEndpoint", "continuationCommand", "token")
          json.field "continuation", extract_channel_community_cursor(cont.as_s)
        end
      end
    end
  end

  if format == "html"
    response = JSON.parse(response)
    content_html = IV::Frontend::Comments.template_youtube(response, locale, thin_mode, ucid, "community")

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
