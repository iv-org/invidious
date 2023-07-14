module Invidious::Comments
  extend self

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
end
