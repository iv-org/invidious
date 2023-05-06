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
