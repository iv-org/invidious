def text_to_parsed_content(text : String) : JSON::Any
  nodes = [] of JSON::Any
  # For each line convert line to array of nodes
  text.split('\n').each do |line|
    # In first case line is just a simple node before
    # check patterns inside line
    # { 'text': line }
    current_nodes = [] of JSON::Any
    initial_node = {"text" => line}
    current_nodes << (JSON.parse(initial_node.to_json))

    # For each match with url pattern, get last node and preserve
    # last node before create new node with url information
    # { 'text': match, 'navigationEndpoint': { 'urlEndpoint' : 'url': match } }
    line.scan(/https?:\/\/[^ ]*/).each do |url_match|
      # Retrieve last node and update node without match
      last_node = current_nodes[-1].as_h
      splitted_last_node = last_node["text"].as_s.split(url_match[0])
      last_node["text"] = JSON.parse(splitted_last_node[0].to_json)
      current_nodes[-1] = JSON.parse(last_node.to_json)
      # Create new node with match and navigation infos
      current_node = {"text" => url_match[0], "navigationEndpoint" => {"urlEndpoint" => {"url" => url_match[0]}}}
      current_nodes << (JSON.parse(current_node.to_json))
      # If text remain after match create new simple node with text after match
      after_node = {"text" => splitted_last_node.size > 1 ? splitted_last_node[1] : ""}
      current_nodes << (JSON.parse(after_node.to_json))
    end

    # After processing of matches inside line
    # Add \n at end of last node for preserve carriage return
    last_node = current_nodes[-1].as_h
    last_node["text"] = JSON.parse("#{last_node["text"]}\n".to_json)
    current_nodes[-1] = JSON.parse(last_node.to_json)

    # Finally add final nodes to nodes returned
    current_nodes.each do |node|
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

    if navigation_endpoint = run.dig?("navigationEndpoint")
      text = parse_link_endpoint(navigation_endpoint, text, video_id)
    end

    text = "<b>#{text}</b>" if run["bold"]?
    text = "<s>#{text}</s>" if run["strikethrough"]?
    text = "<i>#{text}</i>" if run["italics"]?

    # check for custom emojis
    if run["emoji"]?
      if run["emoji"]["isCustomEmoji"]?.try &.as_bool
        if emoji_image = run.dig?("emoji", "image")
          emoji_alt = emoji_image.dig?("accessibility", "accessibilityData", "label").try &.as_s || text
          emoji_thumb = emoji_image["thumbnails"][0]
          text = String.build do |str|
            str << %(<img alt=") << emoji_alt << "\" "
            str << %(src="/ggpht) << URI.parse(emoji_thumb["url"].as_s).request_target << "\" "
            str << %(title=") << emoji_alt << "\" "
            str << %(width=") << emoji_thumb["width"] << "\" "
            str << %(height=") << emoji_thumb["height"] << "\" "
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
