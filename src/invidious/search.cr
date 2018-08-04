def search(query, page = 1)
  client = make_client(YT_URL)
  html = client.get("/results?q=#{URI.escape(query)}&page=#{page}&sp=EgIQAVAU").body
  html = XML.parse_html(html)

  videos = [] of ChannelVideo

  html.xpath_nodes(%q(//ol[@class="item-section"]/li)).each do |item|
    root = item.xpath_node(%q(div[contains(@class,"yt-lockup-video")]/div))
    if !root
      next
    end

    id = root.xpath_node(%q(.//div[contains(@class,"yt-lockup-thumbnail")]/a/@href)).not_nil!.content.lchop("/watch?v=")

    title = root.xpath_node(%q(.//div[@class="yt-lockup-content"]/h3/a)).not_nil!.content

    author = root.xpath_node(%q(.//div[@class="yt-lockup-content"]/div/a)).not_nil!
    ucid = author["href"].rpartition("/")[-1]
    author = author.content

    published = root.xpath_node(%q(.//ul[@class="yt-lockup-meta-info"]/li[1])).not_nil!.content
    published = decode_date(published)

    video = ChannelVideo.new(id, title, published, Time.now, ucid, author)
    videos << video
  end

  return videos
end
