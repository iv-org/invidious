class RedditThing
  JSON.mapping({
    kind: String,
    data: RedditComment | RedditLink | RedditMore | RedditListing,
  })
end

class RedditComment
  module TimeConverter
    def self.from_json(value : JSON::PullParser) : Time
      Time.unix(value.read_float.to_i)
    end

    def self.to_json(value : Time, json : JSON::Builder)
      json.number(value.to_unix)
    end
  end

  JSON.mapping({
    author:      String,
    body_html:   String,
    replies:     RedditThing | String,
    score:       Int32,
    depth:       Int32,
    created_utc: {
      type:      Time,
      converter: RedditComment::TimeConverter,
    },
  })
end

struct RedditLink
  JSON.mapping({
    author:       String,
    score:        Int32,
    subreddit:    String,
    num_comments: Int32,
    id:           String,
    permalink:    String,
    title:        String,
  })
end

struct RedditMore
  JSON.mapping({
    children: Array(String),
    count:    Int32,
    depth:    Int32,
  })
end

class RedditListing
  JSON.mapping({
    children: Array(RedditThing),
    modhash:  String,
  })
end

def fetch_youtube_comments(id, db, continuation, proxies, format, locale, thin_mode, region, sort_by = "top")
  video = get_video(id, db, proxies, region: region)
  session_token = video.info["session_token"]?

  ctoken = produce_comment_continuation(id, cursor: "", sort_by: sort_by)
  continuation ||= ctoken

  if !continuation || !session_token
    if format == "json"
      return {"comments" => [] of String}.to_json
    else
      return {"contentHtml" => "", "commentCount" => 0}.to_json
    end
  end

  post_req = {
    session_token: session_token,
  }

  client = make_client(YT_URL, proxies, video.info["region"]?)
  headers = HTTP::Headers.new

  headers["content-type"] = "application/x-www-form-urlencoded"
  headers["cookie"] = video.info["cookie"]

  headers["x-client-data"] = "CIi2yQEIpbbJAQipncoBCNedygEIqKPKAQ=="
  headers["x-spf-previous"] = "https://www.youtube.com/watch?v=#{id}&gl=US&hl=en&disable_polymer=1&has_verified=1&bpctr=9999999999"
  headers["x-spf-referer"] = "https://www.youtube.com/watch?v=#{id}&gl=US&hl=en&disable_polymer=1&has_verified=1&bpctr=9999999999"

  headers["x-youtube-client-name"] = "1"
  headers["x-youtube-client-version"] = "2.20180719"

  response = client.post("/comment_service_ajax?action_get_comments=1&ctoken=#{continuation}&continuation=#{continuation}&hl=en&gl=US", headers, form: post_req)
  response = JSON.parse(response.body)

  if !response["response"]["continuationContents"]?
    raise translate(locale, "Could not fetch comments")
  end

  response = response["response"]["continuationContents"]
  if response["commentRepliesContinuation"]?
    body = response["commentRepliesContinuation"]
  else
    body = response["itemSectionContinuation"]
  end

  contents = body["contents"]?
  if !contents
    if format == "json"
      return {"comments" => [] of String}.to_json
    else
      return {"contentHtml" => "", "commentCount" => 0}.to_json
    end
  end

  comments = JSON.build do |json|
    json.object do
      if body["header"]?
        comment_count = body["header"]["commentsHeaderRenderer"]["countText"]["simpleText"].as_s.delete("Comments,").to_i
        json.field "commentCount", comment_count
      end

      json.field "videoId", id

      json.field "comments" do
        json.array do
          contents.as_a.each do |node|
            json.object do
              if !response["commentRepliesContinuation"]?
                node = node["commentThreadRenderer"]
              end

              if node["replies"]?
                node_replies = node["replies"]["commentRepliesRenderer"]
              end

              if !response["commentRepliesContinuation"]?
                node_comment = node["comment"]["commentRenderer"]
              else
                node_comment = node["commentRenderer"]
              end

              content_html = node_comment["contentText"]["simpleText"]?.try &.as_s.rchop('\ufeff').try { |block| HTML.escape(block) }.to_s ||
                             content_to_comment_html(node_comment["contentText"]["runs"].as_a).try &.to_s || ""

              author = node_comment["authorText"]?.try &.["simpleText"]
              author ||= ""

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
              json.field "published", published.to_unix
              json.field "publishedText", translate(locale, "`x` ago", recode_date(published, locale))
              json.field "likeCount", node_comment["likeCount"]
              json.field "commentId", node_comment["commentId"]
              json.field "authorIsChannelOwner", node_comment["authorIsChannelOwner"]

              if node_comment["actionButtons"]["commentActionButtonsRenderer"]["creatorHeart"]?
                hearth_data = node_comment["actionButtons"]["commentActionButtonsRenderer"]["creatorHeart"]["creatorHeartRenderer"]["creatorThumbnail"]
                json.field "creatorHeart" do
                  json.object do
                    json.field "creatorThumbnail", hearth_data["thumbnails"][-1]["url"]
                    json.field "creatorName", hearth_data["accessibility"]["accessibilityData"]["label"]
                  end
                end
              end

              if node_replies && !response["commentRepliesContinuation"]?
                reply_count = node_replies["moreText"]["simpleText"].as_s.delete("View all reply replies,")
                if reply_count.empty?
                  reply_count = 1
                else
                  reply_count = reply_count.try &.to_i?
                  reply_count ||= 1
                end

                continuation = node_replies["continuations"]?.try &.as_a[0]["nextContinuationData"]["continuation"].as_s
                continuation ||= ""

                json.field "replies" do
                  json.object do
                    json.field "replyCount", reply_count
                    json.field "continuation", continuation
                  end
                end
              end
            end
          end
        end
      end

      if body["continuations"]?
        continuation = body["continuations"][0]["nextContinuationData"]["continuation"]
        json.field "continuation", continuation
      end
    end
  end

  if format == "html"
    comments = JSON.parse(comments)
    content_html = template_youtube_comments(comments, locale, thin_mode)

    comments = JSON.build do |json|
      json.object do
        json.field "contentHtml", content_html

        if comments["commentCount"]?
          json.field "commentCount", comments["commentCount"]
        else
          json.field "commentCount", 0
        end
      end
    end
  end

  return comments
end

def fetch_reddit_comments(id, sort_by = "confidence")
  client = make_client(REDDIT_URL)
  headers = HTTP::Headers{"User-Agent" => "web:invidious:v#{CURRENT_VERSION} (by /u/omarroth)"}

  # TODO: Use something like #479 for a static list of instances to use here
  query = "(url:3D#{id}%20OR%20url:#{id})%20(site:invidio.us%20OR%20site:youtube.com%20OR%20site:youtu.be)"
  search_results = client.get("/search.json?q=#{query}", headers)

  if search_results.status_code == 200
    search_results = RedditThing.from_json(search_results.body)

    # For videos that have more than one thread, choose the one with the highest score
    thread = search_results.data.as(RedditListing).children.sort_by { |child| child.data.as(RedditLink).score }[-1]
    thread = thread.data.as(RedditLink)

    result = client.get("/r/#{thread.subreddit}/comments/#{thread.id}.json?limit=100&sort=#{sort_by}", headers).body
    result = Array(RedditThing).from_json(result)
  elsif search_results.status_code == 302
    # Previously, if there was only one result then the API would redirect to that result.
    # Now, it appears it will still return a listing so this section is likely unnecessary.

    result = client.get(search_results.headers["Location"], headers).body
    result = Array(RedditThing).from_json(result)

    thread = result[0].data.as(RedditListing).children[0].data.as(RedditLink)
  else
    raise "Got error code #{search_results.status_code}"
  end

  comments = result[1].data.as(RedditListing).children
  return comments, thread
end

def template_youtube_comments(comments, locale, thin_mode)
  html = ""

  root = comments["comments"].as_a
  root.each do |child|
    if child["replies"]?
      replies_html = <<-END_HTML
      <div id="replies" class="pure-g">
        <div class="pure-u-1-24"></div>
        <div class="pure-u-23-24">
          <p>
            <a href="javascript:void(0)" data-continuation="#{child["replies"]["continuation"]}"
              onclick="get_youtube_replies(this)">#{translate(locale, "View `x` replies", child["replies"]["replyCount"].to_s)}</a>
          </p>
        </div>
      </div>
      END_HTML
    end

    if !thin_mode
      author_thumbnail = "/ggpht#{URI.parse(child["authorThumbnails"][-1]["url"].as_s).full_path}"
    else
      author_thumbnail = ""
    end

    html += <<-END_HTML
    <div class="pure-g">
      <div class="pure-u-4-24 pure-u-md-2-24">
        <img style="width:90%;padding-right:1em;padding-top:1em" src="#{author_thumbnail}">
      </div>
      <div class="pure-u-20-24 pure-u-md-22-24">
        <p>
          <b>
            <a class="#{child["authorIsChannelOwner"] == true ? "channel-owner" : ""}" href="#{child["authorUrl"]}">#{child["author"]}</a>
          </b>
          <p style="white-space:pre-wrap">#{child["contentHtml"]}</p>
          <span title="#{Time.unix(child["published"].as_i64).to_s(translate(locale, "%A %B %-d, %Y"))}">#{translate(locale, "`x` ago", recode_date(Time.unix(child["published"].as_i64), locale))} #{child["isEdited"] == true ? translate(locale, "(edited)") : ""}</span>
          |
          <a href="https://www.youtube.com/watch?v=#{comments["videoId"]}&lc=#{child["commentId"]}" title="#{translate(locale, "YouTube comment permalink")}">[YT]</a>
          |
          <i class="icon ion-ios-thumbs-up"></i> #{number_with_separator(child["likeCount"])}
    END_HTML

    if child["creatorHeart"]?
      if !thin_mode
        creator_thumbnail = "/ggpht#{URI.parse(child["creatorHeart"]["creatorThumbnail"].as_s).full_path}"
      else
        creator_thumbnail = ""
      end

      html += <<-END_HTML
          <span class="creator-heart-container" title="#{translate(locale, "`x` marked it with a ❤", child["creatorHeart"]["creatorName"].as_s)}">
              <div class="creator-heart">
                  <img class="creator-heart-background-hearted" src="#{creator_thumbnail}"></img>
                  <div class="creator-heart-small-hearted">
                      <div class="icon ion-ios-heart creator-heart-small-container"></div>
                  </div>
              </div>
          </span>
      END_HTML
    end

    html += <<-END_HTML
        </p>
        #{replies_html}
      </div>
    </div>
    END_HTML
  end

  if comments["continuation"]?
    html += <<-END_HTML
    <div class="pure-g">
      <div class="pure-u-1">
        <p>
          <a href="javascript:void(0)" data-continuation="#{comments["continuation"]}"
            onclick="get_youtube_replies(this, true)">#{translate(locale, "Load more")}</a>
        </p>
      </div>
    </div>
    END_HTML
  end

  return html
end

def template_reddit_comments(root, locale)
  html = ""
  root.each do |child|
    if child.data.is_a?(RedditComment)
      child = child.data.as(RedditComment)
      author = child.author
      score = child.score
      body_html = HTML.unescape(child.body_html)

      replies_html = ""
      if child.replies.is_a?(RedditThing)
        replies = child.replies.as(RedditThing)
        replies_html = template_reddit_comments(replies.data.as(RedditListing).children, locale)
      end

      content = <<-END_HTML
      <p>
        <a href="javascript:void(0)" onclick="toggle_parent(this)">[ - ]</a>
        <b><a href="https://www.reddit.com/user/#{author}">#{author}</a></b>
        #{translate(locale, "`x` points", number_with_separator(score))}
        #{translate(locale, "`x` ago", recode_date(child.created_utc, locale))}
      </p>
      <div>
      #{body_html}
      #{replies_html}
      </div>
      END_HTML

      if child.depth > 0
        html += <<-END_HTML
          <div class="pure-g">
          <div class="pure-u-1-24">
          </div>
          <div class="pure-u-23-24">
          #{content}
          </div>
          </div>
        END_HTML
      else
        html += <<-END_HTML
          <div class="pure-g">
          <div class="pure-u-1">
          #{content}
          </div>
          </div>
        END_HTML
      end
    end
  end

  return html
end

def replace_links(html)
  html = XML.parse_html(html)

  html.xpath_nodes(%q(//a)).each do |anchor|
    url = URI.parse(anchor["href"])

    if {"www.youtube.com", "m.youtube.com", "youtu.be"}.includes?(url.host)
      if url.path == "/redirect"
        params = HTTP::Params.parse(url.query.not_nil!)
        anchor["href"] = params["q"]?
      else
        anchor["href"] = url.full_path
      end
    elsif url.to_s == "#"
      begin
        length_seconds = decode_length_seconds(anchor.content)
      rescue ex
        length_seconds = decode_time(anchor.content)
      end

      anchor["href"] = "javascript:void(0)"
      anchor["onclick"] = "player.currentTime(#{length_seconds})"
    end
  end

  html = html.xpath_node(%q(//body)).not_nil!
  if node = html.xpath_node(%q(./p))
    html = node
  end

  return html.to_xml(options: XML::SaveOptions::NO_DECL)
end

def fill_links(html, scheme, host)
  html = XML.parse_html(html)

  html.xpath_nodes("//a").each do |match|
    url = URI.parse(match["href"])
    # Reddit links don't have host
    if !url.host && !match["href"].starts_with?("javascript") && !url.to_s.ends_with? "#"
      url.scheme = scheme
      url.host = host
      match["href"] = url
    end
  end

  if host == "www.youtube.com"
    html = html.xpath_node(%q(//body/p)).not_nil!
  end

  return html.to_xml(options: XML::SaveOptions::NO_DECL)
end

def content_to_comment_html(content)
  comment_html = content.map do |run|
    text = HTML.escape(run["text"].as_s)

    if run["text"] == "\n"
      text = "<br>"
    end

    if run["bold"]?
      text = "<b>#{text}</b>"
    end

    if run["italics"]?
      text = "<i>#{text}</i>"
    end

    if run["navigationEndpoint"]?
      if url = run["navigationEndpoint"]["urlEndpoint"]?.try &.["url"].as_s
        url = URI.parse(url)

        if !url.host || {"m.youtube.com", "www.youtube.com", "youtu.be"}.includes? url.host
          if url.path == "/redirect"
            url = HTTP::Params.parse(url.query.not_nil!)["q"]
          else
            url = url.full_path
          end
        end

        text = %(<a href="#{url}">#{text}</a>)
      elsif watch_endpoint = run["navigationEndpoint"]["watchEndpoint"]?
        length_seconds = watch_endpoint["startTimeSeconds"]?
        video_id = watch_endpoint["videoId"].as_s

        if length_seconds
          text = %(<a href="javascript:void(0)" onclick="player.currentTime(#{length_seconds})">#{text}</a>)
        else
          text = %(<a href="/watch?v=#{video_id}">#{text}</a>)
        end
      elsif url = run["navigationEndpoint"]["commandMetadata"]?.try &.["webCommandMetadata"]["url"].as_s
        text = %(<a href="#{url}">#{text}</a>)
      end
    end

    text
  end.join.rchop('\ufeff')

  return comment_html
end

def produce_comment_continuation(video_id, cursor = "", sort_by = "top")
  continuation = IO::Memory.new

  continuation.write(Bytes[0x12, 0x26])

  continuation.write(Bytes[0x12, video_id.size])
  continuation.print(video_id)

  continuation.write(Bytes[0xc0, 0x01, 0x01])
  continuation.write(Bytes[0xc8, 0x01, 0x01])
  continuation.write(Bytes[0xe0, 0x01, 0x01])

  continuation.write(Bytes[0xa2, 0x02, 0x0d])
  continuation.write(Bytes[0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01])

  continuation.write(Bytes[0x40, 0x00])
  continuation.write(Bytes[0x18, 0x06])

  if cursor.empty?
    continuation.write(Bytes[0x32])
    continuation.write(write_var_int(video_id.size + 8))

    continuation.write(Bytes[0x22, video_id.size + 4])
    continuation.write(Bytes[0x22, video_id.size])
    continuation.print(video_id)

    case sort_by
    when "top"
      continuation.write(Bytes[0x30, 0x00])
    when "new", "newest"
      continuation.write(Bytes[0x30, 0x01])
    end

    continuation.write(Bytes[0x78, 0x02])
  else
    continuation.write(Bytes[0x32])
    continuation.write(write_var_int(cursor.size + video_id.size + 11))

    continuation.write(Bytes[0x0a])
    continuation.write(write_var_int(cursor.size))
    continuation.print(cursor)

    continuation.write(Bytes[0x22, video_id.size + 4])
    continuation.write(Bytes[0x22, video_id.size])
    continuation.print(video_id)

    case sort_by
    when "top"
      continuation.write(Bytes[0x30, 0x00])
    when "new", "newest"
      continuation.write(Bytes[0x30, 0x01])
    end

    continuation.write(Bytes[0x28, 0x14])
  end

  continuation.rewind
  continuation = continuation.gets_to_end

  continuation = Base64.urlsafe_encode(continuation.to_slice)
  continuation = URI.escape(continuation)

  return continuation
end

def produce_comment_reply_continuation(video_id, ucid, comment_id)
  continuation = IO::Memory.new

  continuation.write(Bytes[0x12, 0x26])

  continuation.write(Bytes[0x12, video_id.size])
  continuation.print(video_id)

  continuation.write(Bytes[0xc0, 0x01, 0x01])
  continuation.write(Bytes[0xc8, 0x01, 0x01])
  continuation.write(Bytes[0xe0, 0x01, 0x01])

  continuation.write(Bytes[0xa2, 0x02, 0x0d])
  continuation.write(Bytes[0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01])

  continuation.write(Bytes[0x40, 0x00])
  continuation.write(Bytes[0x18, 0x06])

  continuation.write(Bytes[0x32, ucid.size + video_id.size + comment_id.size + 16])
  continuation.write(Bytes[0x1a, ucid.size + video_id.size + comment_id.size + 14])

  continuation.write(Bytes[0x12, comment_id.size])
  continuation.print(comment_id)

  continuation.write(Bytes[0x22, 0x02, 0x08, 0x00]) # ??

  continuation.write(Bytes[ucid.size + video_id.size + 7])
  continuation.write(Bytes[ucid.size])
  continuation.print(ucid)
  continuation.write(Bytes[0x32, video_id.size])
  continuation.print(video_id)
  continuation.write(Bytes[0x40, 0x01])
  continuation.write(Bytes[0x48, 0x0a])

  continuation.rewind
  continuation = continuation.gets_to_end

  continuation = Base64.urlsafe_encode(continuation.to_slice)
  continuation = URI.escape(continuation)

  return continuation
end
