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

class RedditLink
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

class RedditMore
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

def fetch_youtube_comments(id, continuation, proxies, format)
  client = make_client(YT_URL)
  html = client.get("/watch?v=#{id}&gl=US&hl=en&disable_polymer=1&has_verified=1&bpctr=9999999999")
  headers = HTTP::Headers.new
  headers["cookie"] = html.cookies.add_request_headers(headers)["cookie"]
  body = html.body

  session_token = body.match(/'XSRF_TOKEN': "(?<session_token>[A-Za-z0-9\_\-\=]+)"/).not_nil!["session_token"]
  itct = body.match(/itct=(?<itct>[^"]+)"/).not_nil!["itct"]
  ctoken = body.match(/'COMMENTS_TOKEN': "(?<ctoken>[^"]+)"/)

  if body.match(/<meta itemprop="regionsAllowed" content="">/)
    bypass_channel = Channel({String, HTTPClient, HTTP::Headers} | Nil).new

    proxies.each do |region, list|
      spawn do
        proxy_html = %(<meta itemprop="regionsAllowed" content="">)

        list.each do |proxy|
          begin
            proxy_client = HTTPClient.new(YT_URL)
            proxy_client.read_timeout = 10.seconds
            proxy_client.connect_timeout = 10.seconds

            proxy = HTTPProxy.new(proxy_host: proxy[:ip], proxy_port: proxy[:port])
            proxy_client.set_proxy(proxy)

            response = proxy_client.get("/watch?v=#{id}&gl=US&hl=en&disable_polymer=1&has_verified=1&bpctr=9999999999")
            proxy_headers = HTTP::Headers.new
            proxy_headers["cookie"] = response.cookies.add_request_headers(headers)["cookie"]
            proxy_html = response.body

            if !proxy_html.match(/<meta itemprop="regionsAllowed" content="">/)
              bypass_channel.send({proxy_html, proxy_client, proxy_headers})
              break
            end
          rescue ex
          end
        end

        # If none of the proxies we tried returned a valid response
        if proxy_html.match(/<meta itemprop="regionsAllowed" content="">/)
          bypass_channel.send(nil)
        end
      end
    end

    proxies.size.times do
      response = bypass_channel.receive
      if response
        session_token = response[0].match(/'XSRF_TOKEN': "(?<session_token>[A-Za-z0-9\_\-\=]+)"/).not_nil!["session_token"]
        itct = response[0].match(/itct=(?<itct>[^"]+)"/).not_nil!["itct"]
        ctoken = response[0].match(/'COMMENTS_TOKEN': "(?<ctoken>[^"]+)"/)

        client = response[1]
        headers = response[2]
        break
      end
    end
  end

  if !ctoken
    if format == "json"
      return {"comments" => [] of String}.to_json
    else
      return {"contentHtml" => "", "commentCount" => 0}.to_json
    end
  end
  ctoken = ctoken["ctoken"]

  if !continuation.empty?
    ctoken = continuation
  else
    continuation = ctoken
  end

  post_req = {
    "session_token" => session_token,
  }
  post_req = HTTP::Params.encode(post_req)

  headers["content-type"] = "application/x-www-form-urlencoded"

  headers["x-client-data"] = "CIi2yQEIpbbJAQipncoBCNedygEIqKPKAQ=="
  headers["x-spf-previous"] = "https://www.youtube.com/watch?v=#{id}&gl=US&hl=en&disable_polymer=1&has_verified=1&bpctr=9999999999"
  headers["x-spf-referer"] = "https://www.youtube.com/watch?v=#{id}&gl=US&hl=en&disable_polymer=1&has_verified=1&bpctr=9999999999"

  headers["x-youtube-client-name"] = "1"
  headers["x-youtube-client-version"] = "2.20180719"
  response = client.post("/comment_service_ajax?action_get_comments=1&pbj=1&ctoken=#{ctoken}&continuation=#{continuation}&itct=#{itct}&hl=en&gl=US", headers, post_req)
  response = JSON.parse(response.body)

  if !response["response"]["continuationContents"]?
    raise "Could not fetch comments"
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

              content_html = node_comment["contentText"]["simpleText"]?.try &.as_s.rchop('\ufeff')
              if content_html
                content_html = HTML.escape(content_html)
              end

              content_html ||= content_to_comment_html(node_comment["contentText"]["runs"].as_a)
              content_html, content = html_to_content(content_html)

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

              published = decode_date(node_comment["publishedTimeText"]["runs"][0]["text"].as_s.rchop(" (edited)"))

              json.field "content", content
              json.field "contentHtml", content_html
              json.field "published", published.to_unix
              json.field "publishedText", "#{recode_date(published)} ago"
              json.field "likeCount", node_comment["likeCount"]
              json.field "commentId", node_comment["commentId"]

              if node_replies && !response["commentRepliesContinuation"]?
                reply_count = node_replies["moreText"]["simpleText"].as_s.delete("View all reply replies,")
                if reply_count.empty?
                  reply_count = 1
                else
                  reply_count = reply_count.try &.to_i?
                  reply_count ||= 1
                end

                continuation = node_replies["continuations"].as_a[0]["nextContinuationData"]["continuation"].as_s

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
    content_html = template_youtube_comments(comments)

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

def fetch_reddit_comments(id)
  client = make_client(REDDIT_URL)
  headers = HTTP::Headers{"User-Agent" => "web:invidio.us:v0.11.0 (by /u/omarroth)"}

  query = "(url:3D#{id}%20OR%20url:#{id})%20(site:youtube.com%20OR%20site:youtu.be)"
  search_results = client.get("/search.json?q=#{query}", headers)

  if search_results.status_code == 200
    search_results = RedditThing.from_json(search_results.body)

    thread = search_results.data.as(RedditListing).children.sort_by { |child| child.data.as(RedditLink).score }[-1]
    thread = thread.data.as(RedditLink)

    result = client.get("/r/#{thread.subreddit}/comments/#{thread.id}.json?limit=100&sort=top", headers).body
    result = Array(RedditThing).from_json(result)
  elsif search_results.status_code == 302
    result = client.get(search_results.headers["Location"], headers).body
    result = Array(RedditThing).from_json(result)

    thread = result[0].data.as(RedditListing).children[0].data.as(RedditLink)
  else
    raise "Got error code #{search_results.status_code}"
  end

  comments = result[1].data.as(RedditListing).children
  return comments, thread
end

def template_youtube_comments(comments)
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
              onclick="get_youtube_replies(this)">View #{child["replies"]["replyCount"]} replies</a>
          </p>
        </div>
      </div>
      END_HTML
    end

    author_thumbnail = "/ggpht#{URI.parse(child["authorThumbnails"][-1]["url"].as_s).full_path}"

    html += <<-END_HTML
    <div class="pure-g">
      <div class="pure-u-4-24 pure-u-md-2-24">
        <img style="width:90%; padding-right:1em; padding-top:1em;" src="#{author_thumbnail}">
      </div>
      <div class="pure-u-20-24 pure-u-md-22-24">
        <p>
          <b>
            <a href="#{child["authorUrl"]}">#{child["author"]}</a>
          </b> 
          <p style="white-space:pre-wrap">#{child["contentHtml"]}</p>
          #{recode_date(Time.unix(child["published"].as_i64))} ago
          | 
          <i class="icon ion-ios-thumbs-up"></i> #{number_with_separator(child["likeCount"])} 
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
            onclick="get_youtube_replies(this, true)">Load more</a>
        </p>
      </div>
    </div>
    END_HTML
  end

  return html
end

def template_reddit_comments(root)
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
        replies_html = template_reddit_comments(replies.data.as(RedditListing).children)
      end

      content = <<-END_HTML
      <p>
        <a href="javascript:void(0)" onclick="toggle_parent(this)">[ - ]</a> 
        <b><a href="https://www.reddit.com/user/#{author}">#{author}</a></b> 
        #{number_with_separator(score)} points 
        #{recode_date(child.created_utc)} ago
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

  html = html.to_xml(options: XML::SaveOptions::NO_DECL)
  return html
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
    html = html.xpath_node(%q(//body)).not_nil!.to_xml
  else
    html = html.to_xml(options: XML::SaveOptions::NO_DECL)
  end

  return html
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
      url = run["navigationEndpoint"]["urlEndpoint"]?.try &.["url"].as_s
      if url
        url = URI.parse(url)

        if !url.host || {"m.youtube.com", "www.youtube.com", "youtu.be"}.includes? url.host
          if url.path == "/redirect"
            url = HTTP::Params.parse(url.query.not_nil!)["q"]
          else
            url = url.full_path
          end
        end
      else
        url = run["navigationEndpoint"]["commandMetadata"]?.try &.["webCommandMetadata"]["url"].as_s
      end

      text = %(<a href="#{url}">#{text}</a>)
    end

    text
  end.join.rchop('\ufeff')

  return comment_html
end
