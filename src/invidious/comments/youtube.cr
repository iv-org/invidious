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
    return parse_youtube(id, response, format, locale, thin_mode, sort_by)
  end

  def fetch_community_post_comments(ucid, post_id)
    object = {
      "2:string"    => "community",
      "25:embedded" => {
        "22:string" => post_id,
      },
      "45:embedded" => {
        "2:varint" => 1_i64,
        "3:varint" => 1_i64,
      },
      "53:embedded" => {
        "4:embedded" => {
          "6:varint"  => 0_i64,
          "27:varint" => 1_i64,
          "29:string" => post_id,
          "30:string" => ucid,
        },
        "8:string" => "comments-section",
      },
    }

    object_parsed = object.try { |i| Protodec::Any.cast_json(i) }
      .try { |i| Protodec::Any.from_json(i) }
      .try { |i| Base64.urlsafe_encode(i) }

    object2 = {
      "80226972:embedded" => {
        "2:string" => ucid,
        "3:string" => object_parsed,
      },
    }

    continuation = object2.try { |i| Protodec::Any.cast_json(i) }
      .try { |i| Protodec::Any.from_json(i) }
      .try { |i| Base64.urlsafe_encode(i) }
      .try { |i| URI.encode_www_form(i) }

    initial_data = YoutubeAPI.browse(continuation: continuation)
    return initial_data
  end

  def parse_youtube(id, response, format, locale, thin_mode, sort_by = "top", type = "video", ucid = nil)
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

    mutations = response.dig?("frameworkUpdates", "entityBatchUpdate", "mutations").try &.as_a || [] of JSON::Any

    response = JSON.build do |json|
      json.object do
        if header
          count_text = header["commentsHeaderRenderer"]["countText"]
          comment_count = (count_text["simpleText"]? || count_text["runs"]?.try &.[0]?.try &.["text"]?)
            .try &.as_s.gsub(/\D/, "").to_i? || 0
          json.field "commentCount", comment_count
        end

        if !ucid.nil?
          json.field "authorId", ucid
        end

        if type == "post"
          json.field "postId", id
        else
          json.field "videoId", id
        end

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

                if cvm = node["commentViewModel"]?
                  # two commentViewModels for inital request
                  # one commentViewModel when getting a replies to a comment
                  cvm = cvm["commentViewModel"] if cvm["commentViewModel"]?

                  comment_key = cvm["commentKey"]
                  toolbar_key = cvm["toolbarStateKey"]
                  comment_mutation = mutations.find { |i| i.dig?("payload", "commentEntityPayload", "key") == comment_key }
                  toolbar_mutation = mutations.find { |i| i.dig?("entityKey") == toolbar_key }

                  if !comment_mutation.nil? && !toolbar_mutation.nil?
                    # todo parse styleRuns, commandRuns and attachmentRuns for comments
                    html_content = parse_description(comment_mutation.dig("payload", "commentEntityPayload", "properties", "content"), id)
                    comment_author = comment_mutation.dig("payload", "commentEntityPayload", "author")
                    json.field "authorId", comment_author["channelId"].as_s
                    json.field "authorUrl", "/channel/#{comment_author["channelId"].as_s}"
                    json.field "author", comment_author["displayName"].as_s
                    json.field "verified", comment_author["isVerified"].as_bool
                    json.field "authorThumbnails" do
                      json.array do
                        comment_mutation.dig?("payload", "commentEntityPayload", "avatar", "image", "sources").try &.as_a.each do |thumbnail|
                          json.object do
                            json.field "url", thumbnail["url"]
                            json.field "width", thumbnail["width"]
                            json.field "height", thumbnail["height"]
                          end
                        end
                      end
                    end

                    json.field "authorIsChannelOwner", comment_author["isCreator"].as_bool
                    json.field "isSponsor", (comment_author["sponsorBadgeUrl"]? != nil)

                    if sponsor_badge_url = comment_author["sponsorBadgeUrl"]?
                      # Sponsor icon thumbnails always have one object and there's only ever the url property in it
                      json.field "sponsorIconUrl", sponsor_badge_url
                    end

                    comment_toolbar = comment_mutation.dig("payload", "commentEntityPayload", "toolbar")
                    json.field "likeCount", short_text_to_number(comment_toolbar["likeCountNotliked"].as_s)
                    reply_count = short_text_to_number(comment_toolbar["replyCount"]?.try &.as_s || "0")

                    if heart_state = toolbar_mutation.dig?("payload", "engagementToolbarStateEntityPayload", "heartState")
                      if heart_state.as_s == "TOOLBAR_HEART_STATE_HEARTED"
                        json.field "creatorHeart" do
                          json.object do
                            json.field "creatorThumbnail", comment_toolbar["creatorThumbnailUrl"].as_s
                            json.field "creatorName", comment_toolbar["heartActiveTooltip"].as_s.sub("❤ by ", "")
                          end
                        end
                      end
                    end

                    published_text = comment_mutation.dig?("payload", "commentEntityPayload", "properties", "publishedTime").try &.as_s
                  end

                  json.field "isPinned", (cvm.dig?("pinnedText") != nil)
                  json.field "commentId", cvm["commentId"]
                else
                  if node["comment"]?
                    node_comment = node["comment"]["commentRenderer"]
                  else
                    node_comment = node["commentRenderer"]
                  end
                  json.field "commentId", node_comment["commentId"]
                  html_content = node_comment["contentText"]?.try { |t| parse_content(t, id) }

                  json.field "verified", (node_comment["authorCommentBadge"]? != nil)

                  json.field "author", node_comment["authorText"]?.try &.["simpleText"]? || ""
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

                  if comment_action_buttons_renderer = node_comment.dig?("actionButtons", "commentActionButtonsRenderer")
                    json.field "likeCount", comment_action_buttons_renderer["likeButton"]["toggleButtonRenderer"]["accessibilityData"]["accessibilityData"]["label"].as_s.scan(/\d/).map(&.[0]).join.to_i
                    if comment_action_buttons_renderer["creatorHeart"]?
                      heart_data = comment_action_buttons_renderer["creatorHeart"]["creatorHeartRenderer"]["creatorThumbnail"]
                      json.field "creatorHeart" do
                        json.object do
                          json.field "creatorThumbnail", heart_data["thumbnails"][-1]["url"]
                          json.field "creatorName", heart_data["accessibility"]["accessibilityData"]["label"]
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

                  json.field "authorIsChannelOwner", node_comment["authorIsChannelOwner"]
                  json.field "isPinned", (node_comment["pinnedCommentBadge"]? != nil)
                  published_text = node_comment["publishedTimeText"]["runs"][0]["text"].as_s

                  json.field "isSponsor", (node_comment["sponsorCommentBadge"]? != nil)
                  if node_comment["sponsorCommentBadge"]?
                    # Sponsor icon thumbnails always have one object and there's only ever the url property in it
                    json.field "sponsorIconUrl", node_comment.dig("sponsorCommentBadge", "sponsorCommentBadgeRenderer", "customBadge", "thumbnails", 0, "url").to_s
                  end

                  reply_count = node_comment["replyCount"]?
                end

                content_html = html_content || ""
                json.field "content", html_to_content(content_html)
                json.field "contentHtml", content_html

                if published_text != nil
                  published_text = published_text.to_s
                  if published_text.includes?(" (edited)")
                    json.field "isEdited", true
                    published = decode_date(published_text.rchop(" (edited)"))
                  else
                    json.field "isEdited", false
                    published = decode_date(published_text)
                  end

                  json.field "published", published.to_unix
                  json.field "publishedText", translate(locale, "`x` ago", recode_date(published, locale))
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
                      json.field "replyCount", reply_count || 1
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
      content_html = Frontend::Comments.template_youtube(response, locale, thin_mode, id, type)

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
