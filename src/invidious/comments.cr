def template_reddit_comments(root, locale)
  String.build do |html|
    root.each do |child|
      if child.data.is_a?(RedditComment)
        child = child.data.as(RedditComment)
        body_html = HTML.unescape(child.body_html)

        replies_html = ""
        if child.replies.is_a?(RedditThing)
          replies = child.replies.as(RedditThing)
          replies_html = template_reddit_comments(replies.data.as(RedditListing).children, locale)
        end

        if child.depth > 0
          html << <<-END_HTML
          <div class="pure-g">
          <div class="pure-u-1-24">
          </div>
          <div class="pure-u-23-24">
          END_HTML
        else
          html << <<-END_HTML
          <div class="pure-g">
          <div class="pure-u-1">
          END_HTML
        end

        html << <<-END_HTML
        <p>
          <a href="javascript:void(0)" data-onclick="toggle_parent">[ − ]</a>
          <b><a href="https://www.reddit.com/user/#{child.author}">#{child.author}</a></b>
          #{translate_count(locale, "comments_points_count", child.score, NumberFormatting::Separator)}
          <span title="#{child.created_utc.to_s(translate(locale, "%a %B %-d %T %Y UTC"))}">#{translate(locale, "`x` ago", recode_date(child.created_utc, locale))}</span>
          <a href="https://www.reddit.com#{child.permalink}" title="#{translate(locale, "permalink")}">#{translate(locale, "permalink")}</a>
          </p>
          <div>
          #{body_html}
          #{replies_html}
        </div>
        </div>
        </div>
        END_HTML
      end
    end
  end
end

def replace_links(html)
  # Check if the document is empty
  # Prevents edge-case bug with Reddit comments, see issue #3115
  if html.nil? || html.empty?
    return html
  end

  html = XML.parse_html(html)

  html.xpath_nodes(%q(//a)).each do |anchor|
    url = URI.parse(anchor["href"])

    if url.host.nil? || url.host.not_nil!.ends_with?("youtube.com") || url.host.not_nil!.ends_with?("youtu.be")
      if url.host.try &.ends_with? "youtu.be"
        url = "/watch?v=#{url.path.lstrip('/')}#{url.query_params}"
      else
        if url.path == "/redirect"
          params = HTTP::Params.parse(url.query.not_nil!)
          anchor["href"] = params["q"]?
        else
          anchor["href"] = url.request_target
        end
      end
    elsif url.to_s == "#"
      begin
        length_seconds = decode_length_seconds(anchor.content)
      rescue ex
        length_seconds = decode_time(anchor.content)
      end

      if length_seconds > 0
        anchor["href"] = "javascript:void(0)"
        anchor["onclick"] = "player.currentTime(#{length_seconds})"
      else
        anchor["href"] = url.request_target
      end
    end
  end

  html = html.xpath_node(%q(//body)).not_nil!
  if node = html.xpath_node(%q(./p))
    html = node
  end

  return html.to_xml(options: XML::SaveOptions::NO_DECL)
end

def fill_links(html, scheme, host)
  # Check if the document is empty
  # Prevents edge-case bug with Reddit comments, see issue #3115
  if html.nil? || html.empty?
    return html
  end

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

def text_to_parsed_content(text : String) : JSON::Any
  nodes = [] of JSON::Any
  # For each line convert line to array of nodes
  text.split('\n').each do |line|
    # In first case line is just a simple node before
    # check patterns inside line
    # { 'text': line }
    currentNodes = [] of JSON::Any
    initialNode = {"text" => line}
    currentNodes << (JSON.parse(initialNode.to_json))

    # For each match with url pattern, get last node and preserve
    # last node before create new node with url information
    # { 'text': match, 'navigationEndpoint': { 'urlEndpoint' : 'url': match } }
    line.scan(/https?:\/\/[^ ]*/).each do |urlMatch|
      # Retrieve last node and update node without match
      lastNode = currentNodes[currentNodes.size - 1].as_h
      splittedLastNode = lastNode["text"].as_s.split(urlMatch[0])
      lastNode["text"] = JSON.parse(splittedLastNode[0].to_json)
      currentNodes[currentNodes.size - 1] = JSON.parse(lastNode.to_json)
      # Create new node with match and navigation infos
      currentNode = {"text" => urlMatch[0], "navigationEndpoint" => {"urlEndpoint" => {"url" => urlMatch[0]}}}
      currentNodes << (JSON.parse(currentNode.to_json))
      # If text remain after match create new simple node with text after match
      afterNode = {"text" => splittedLastNode.size > 1 ? splittedLastNode[1] : ""}
      currentNodes << (JSON.parse(afterNode.to_json))
    end

    # After processing of matches inside line
    # Add \n at end of last node for preserve carriage return
    lastNode = currentNodes[currentNodes.size - 1].as_h
    lastNode["text"] = JSON.parse("#{currentNodes[currentNodes.size - 1]["text"]}\n".to_json)
    currentNodes[currentNodes.size - 1] = JSON.parse(lastNode.to_json)

    # Finally add final nodes to nodes returned
    currentNodes.each do |node|
      nodes << (node)
    end
  end
  return JSON.parse({"runs" => nodes}.to_json)
end

def parse_content(content : JSON::Any, video_id : String? = "") : String
  content["simpleText"]?.try &.as_s.rchop('\ufeff').try { |b| HTML.escape(b) }.to_s ||
    content["runs"]?.try &.as_a.try { |r| content_to_comment_html(r, video_id).try &.to_s.gsub("\n", "<br>") } || ""
end

def content_to_comment_html(content, video_id : String? = "")
  html_array = content.map do |run|
    # Sometimes, there is an empty element.
    # See: https://github.com/iv-org/invidious/issues/3096
    next if run.as_h.empty?

    text = HTML.escape(run["text"].as_s)

    if navigationEndpoint = run.dig?("navigationEndpoint")
      text = parse_link_endpoint(navigationEndpoint, text, video_id)
    end

    text = "<b>#{text}</b>" if run["bold"]?
    text = "<s>#{text}</s>" if run["strikethrough"]?
    text = "<i>#{text}</i>" if run["italics"]?

    # check for custom emojis
    if run["emoji"]?
      if run["emoji"]["isCustomEmoji"]?.try &.as_bool
        if emojiImage = run.dig?("emoji", "image")
          emojiAlt = emojiImage.dig?("accessibility", "accessibilityData", "label").try &.as_s || text
          emojiThumb = emojiImage["thumbnails"][0]
          text = String.build do |str|
            str << %(<img alt=") << emojiAlt << "\" "
            str << %(src="/ggpht) << URI.parse(emojiThumb["url"].as_s).request_target << "\" "
            str << %(title=") << emojiAlt << "\" "
            str << %(width=") << emojiThumb["width"] << "\" "
            str << %(height=") << emojiThumb["height"] << "\" "
            str << %(class="channel-emoji" />)
          end
        else
          # Hide deleted channel emoji
          text = ""
        end
      end
    end

    text
  end

  return html_array.join("").delete('\ufeff')
end

def produce_comment_continuation(video_id, cursor = "", sort_by = "top")
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
