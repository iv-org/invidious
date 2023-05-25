module Invidious::Comments
  extend self

  def fetch_youtube(id, cursor, format, locale, thin_mode, region, sort_by = "top")
    case cursor
    when nil, ""
      ctoken = Comments.produce_continuation(id, cursor: "", sort_by: sort_by)
    when .starts_with? "ADSJ"
      ctoken = Comments.produce_continuation(id, cursor: cursor, sort_by: sort_by)
    else
      ctoken = cursor
    end

    client_config = YoutubeAPI::ClientConfig.new(region: region)
    response = YoutubeAPI.next(continuation: ctoken, client_config: client_config)
    contents = nil

    if on_response_received_endpoints = response["onResponseReceivedEndpoints"]?
      header = nil
      on_response_received_endpoints.as_a.each do |item|
        if item["reloadContinuationItemsCommand"]?
          case item["reloadContinuationItemsCommand"]["slot"]
          when "RELOAD_CONTINUATION_SLOT_HEADER"
            header = item["reloadContinuationItemsCommand"]["continuationItems"][0]
          when "RELOAD_CONTINUATION_SLOT_BODY"
            # continuationItems is nil when video has no comments
            contents = item["reloadContinuationItemsCommand"]["continuationItems"]?
          end
        elsif item["appendContinuationItemsAction"]?
          contents = item["appendContinuationItemsAction"]["continuationItems"]
        end
      end
    elsif response["continuationContents"]?
      response = response["continuationContents"]
      if response["commentRepliesContinuation"]?
        body = response["commentRepliesContinuation"]
      else
        body = response["itemSectionContinuation"]
      end
      contents = body["contents"]?
      header = body["header"]?
    else
      raise NotFoundException.new("Comments not found.")
    end

    if !contents
      if format == "json"
        return {"comments" => [] of String}.to_json
      else
        return {"contentHtml" => "", "commentCount" => 0}.to_json
      end
    end

    continuation_item_renderer = nil
    contents.as_a.reject! do |item|
      if item["continuationItemRenderer"]?
        continuation_item_renderer = item["continuationItemRenderer"]
        true
      end
    end

    response = JSON.build do |json|
      json.object do
        if header
          count_text = header["commentsHeaderRenderer"]["countText"]
          comment_count = (count_text["simpleText"]? || count_text["runs"]?.try &.[0]?.try &.["text"]?)
            .try &.as_s.gsub(/\D/, "").to_i? || 0
          json.field "commentCount", comment_count
        end

        json.field "videoId", id

        json.field "comments" do
          json.array do
            contents.as_a.each do |node|
              json.object do
                if node["commentThreadRenderer"]?
                  node = node["commentThreadRenderer"]
                end

                if node["replies"]?
                  node_replies = node["replies"]["commentRepliesRenderer"]
                end

                if node["comment"]?
                  node_comment = node["comment"]["commentRenderer"]
                else
                  node_comment = node["commentRenderer"]
                end

                content_html = node_comment["contentText"]?.try { |t| parse_content(t, id) } || ""
                author = node_comment["authorText"]?.try &.["simpleText"]? || ""

                json.field "verified", (node_comment["authorCommentBadge"]? != nil)

                json.field "author", author
                json.field "authorThumbnails" do
                  json.array do
                    node_comment["authorThumbnail"]["thumbnails"].as_a.each do |thumbnail|
                      json.object do
                        json.field "url", thumbnail["url"]
                        json.field "width", thumbnail["width"]
                        json.field "height", thumbnail["height"]
                      end
                    end
                  end
                end

                if node_comment["authorEndpoint"]?
                  json.field "authorId", node_comment["authorEndpoint"]["browseEndpoint"]["browseId"]
                  json.field "authorUrl", node_comment["authorEndpoint"]["browseEndpoint"]["canonicalBaseUrl"]
                else
                  json.field "authorId", ""
                  json.field "authorUrl", ""
                end

                published_text = node_comment["publishedTimeText"]["runs"][0]["text"].as_s
                published = decode_date(published_text.rchop(" (edited)"))

                if published_text.includes?(" (edited)")
                  json.field "isEdited", true
                else
                  json.field "isEdited", false
                end

                json.field "content", html_to_content(content_html)
                json.field "contentHtml", content_html

                json.field "isPinned", (node_comment["pinnedCommentBadge"]? != nil)
                json.field "isSponsor", (node_comment["sponsorCommentBadge"]? != nil)
                if node_comment["sponsorCommentBadge"]?
                  # Sponsor icon thumbnails always have one object and there's only ever the url property in it
                  json.field "sponsorIconUrl", node_comment.dig("sponsorCommentBadge", "sponsorCommentBadgeRenderer", "customBadge", "thumbnails", 0, "url").to_s
                end
                json.field "published", published.to_unix
                json.field "publishedText", translate(locale, "`x` ago", recode_date(published, locale))

                comment_action_buttons_renderer = node_comment["actionButtons"]["commentActionButtonsRenderer"]

                json.field "likeCount", comment_action_buttons_renderer["likeButton"]["toggleButtonRenderer"]["accessibilityData"]["accessibilityData"]["label"].as_s.scan(/\d/).map(&.[0]).join.to_i
                json.field "commentId", node_comment["commentId"]
                json.field "authorIsChannelOwner", node_comment["authorIsChannelOwner"]

                if comment_action_buttons_renderer["creatorHeart"]?
                  hearth_data = comment_action_buttons_renderer["creatorHeart"]["creatorHeartRenderer"]["creatorThumbnail"]
                  json.field "creatorHeart" do
                    json.object do
                      json.field "creatorThumbnail", hearth_data["thumbnails"][-1]["url"]
                      json.field "creatorName", hearth_data["accessibility"]["accessibilityData"]["label"]
                    end
                  end
                end

                if node_replies && !response["commentRepliesContinuation"]?
                  if node_replies["continuations"]?
                    continuation = node_replies["continuations"]?.try &.as_a[0]["nextContinuationData"]["continuation"].as_s
                  elsif node_replies["contents"]?
                    continuation = node_replies["contents"]?.try &.as_a[0]["continuationItemRenderer"]["continuationEndpoint"]["continuationCommand"]["token"].as_s
                  end
                  continuation ||= ""

                  json.field "replies" do
                    json.object do
                      json.field "replyCount", node_comment["replyCount"]? || 1
                      json.field "continuation", continuation
                    end
                  end
                end
              end
            end
          end
        end

        if continuation_item_renderer
          if continuation_item_renderer["continuationEndpoint"]?
            continuation_endpoint = continuation_item_renderer["continuationEndpoint"]
          elsif continuation_item_renderer["button"]?
            continuation_endpoint = continuation_item_renderer["button"]["buttonRenderer"]["command"]
          end
          if continuation_endpoint
            json.field "continuation", continuation_endpoint["continuationCommand"]["token"].as_s
          end
        end
      end
    end

    if format == "html"
      response = JSON.parse(response)
      content_html = Frontend::Comments.template_youtube(response, locale, thin_mode)

      response = JSON.build do |json|
        json.object do
          json.field "contentHtml", content_html

          if response["commentCount"]?
            json.field "commentCount", response["commentCount"]
          else
            json.field "commentCount", 0
          end
        end
      end
    end

    return response
  end

  def produce_continuation(video_id, cursor = "", sort_by = "top")
    object = {
      "2:embedded" => {
        "2:string"    => video_id,
        "25:varint"   => 0_i64,
        "28:varint"   => 1_i64,
        "36:embedded" => {
          "5:varint" => -1_i64,
          "8:varint" => 0_i64,
        },
        "40:embedded" => {
          "1:varint" => 4_i64,
          "3:string" => "https://www.youtube.com",
          "4:string" => "",
        },
      },
      "3:varint"   => 6_i64,
      "6:embedded" => {
        "1:string"   => cursor,
        "4:embedded" => {
          "4:string" => video_id,
          "6:varint" => 0_i64,
        },
        "5:varint" => 20_i64,
      },
    }

    case sort_by
    when "top"
      object["6:embedded"].as(Hash)["4:embedded"].as(Hash)["6:varint"] = 0_i64
    when "new", "newest"
      object["6:embedded"].as(Hash)["4:embedded"].as(Hash)["6:varint"] = 1_i64
    else # top
      object["6:embedded"].as(Hash)["4:embedded"].as(Hash)["6:varint"] = 0_i64
    end

    continuation = object.try { |i| Protodec::Any.cast_json(i) }
      .try { |i| Protodec::Any.from_json(i) }
      .try { |i| Base64.urlsafe_encode(i) }
      .try { |i| URI.encode_www_form(i) }

    return continuation
  end
end
