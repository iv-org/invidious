class RedditThing
  JSON.mapping({
    kind: String,
    data: RedditComment | RedditLink | RedditMore | RedditListing,
  })
end

class RedditComment
  JSON.mapping({
    author:    String,
    body_html: String,
    replies:   RedditThing | String,
    score:     Int32,
    depth:     Int32,
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
              onclick="load_comments(this)">View #{child["replies"]["replyCount"]} replies</a>
          </p>
        </div>
      </div>
      END_HTML
    end

    html += <<-END_HTML
    <div class="pure-g">
      <div class="pure-u-2-24">
        <img style="width:90%; padding-right:1em; padding-top:1em;" src="#{child["authorThumbnails"][0]["url"]}">
      </div>
      <div class="pure-u-22-24">
        <p>
            <a href="javascript:void(0)" onclick="toggle(this)">[ - ]</a> 
            <i class="icon ion-ios-thumbs-up"></i> #{child["likeCount"]} 
            <b><a href="#{child["authorUrl"]}">#{child["author"]}</a></b> 
            - #{recode_date(Time.epoch(child["published"].as_i64))} ago
          </p>
          <div>
          #{child["content"]}
          #{replies_html}
          </div>
        </div>
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
            onclick="load_comments(this)">Load more</a>
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
        <a href="javascript:void(0)" onclick="toggle(this)">[ - ]</a> 
        <i class="icon ion-ios-thumbs-up"></i> #{score} 
        <b><a href="https://www.reddit.com/user/#{author}">#{author}</a></b> 
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

def add_alt_links(html)
  alt_links = [] of {String, String}

  # This is painful but likely the only way to accomplish this in Crystal,
  # as Crystigiri and others are not able to insert XML Nodes into a document.
  # The goal here is to use as little regex as possible
  html.scan(/<a[^>]*>([^<]+)<\/a>/) do |match|
    anchor = XML.parse_html(match[0])
    anchor = anchor.xpath_node("//a").not_nil!
    url = URI.parse(anchor["href"])

    if ["www.youtube.com", "m.youtube.com"].includes?(url.host)
      if url.path == "/redirect"
        params = HTTP::Params.parse(url.query.not_nil!)
        alt_url = params["q"]?
        alt_url ||= "/"
      else
        alt_url = url.full_path
      end

      alt_link = <<-END_HTML
      <a href="#{alt_url}">
        <i class="icon ion-ios-link"></i>
      </a>
      END_HTML
    elsif url.host == "youtu.be"
      alt_link = <<-END_HTML
      <a href="/watch?v=#{url.path.try &.lchop("/")}&#{url.query}">
        <i class="icon ion-ios-link"></i>
      </a>
      END_HTML
    elsif url.to_s == "#"
      begin
        length_seconds = decode_length_seconds(anchor.content)
      rescue ex
        length_seconds = decode_time(anchor.content)
      end

      alt_anchor = <<-END_HTML
      <a href="javascript:void(0)" onclick="player.currentTime(#{length_seconds})">#{anchor.content}</a>
      END_HTML

      html = html.sub(anchor.to_s, alt_anchor)
      next
    else
      alt_link = ""
    end

    alt_links << {anchor.to_s, alt_link}
  end

  alt_links.each do |original, alternate|
    html = html.sub(original, original + alternate)
  end

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
    html = html.xpath_node(%q(//p[@id="eow-description"])).not_nil!.to_xml
  else
    html = html.to_xml(options: XML::SaveOptions::NO_DECL)
  end

  html
end
