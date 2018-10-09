class RedditThing
  JSON.mapping({
    kind: String,
    data: RedditComment | RedditLink | RedditMore | RedditListing,
  })
end

class RedditComment
  module TimeConverter
    def self.from_json(value : JSON::PullParser) : Time
      Time.epoch(value.read_float.to_i)
    end

    def self.to_json(value : Time, json : JSON::Builder)
      json.number(value.epoch)
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

def get_reddit_comments(id, client, headers)
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
          <a href="javascript:void(0)" onclick="toggle_parent(this)">[ - ]</a> 
          <b>
            <a href="#{child["authorUrl"]}">#{child["author"]}</a>
          </b> 
          <p style="white-space:pre-wrap">#{child["contentHtml"]}</p>
          #{recode_date(Time.epoch(child["published"].as_i64))} ago
          | 
          <i class="icon ion-ios-thumbs-up"></i> #{child["likeCount"]} 
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
            onclick="get_youtube_replies(this)">Load more</a>
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
        #{score} points 
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
