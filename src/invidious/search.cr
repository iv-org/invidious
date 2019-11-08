struct SearchVideo
  def to_xml(host_url, auto_generated, query_params, xml : XML::Builder)
    query_params["v"] = self.id

    xml.element("entry") do
      xml.element("id") { xml.text "yt:video:#{self.id}" }
      xml.element("yt:videoId") { xml.text self.id }
      xml.element("yt:channelId") { xml.text self.ucid }
      xml.element("title") { xml.text self.title }
      xml.element("link", rel: "alternate", href: "#{host_url}/watch?#{query_params}")

      xml.element("author") do
        if auto_generated
          xml.element("name") { xml.text self.author }
          xml.element("uri") { xml.text "#{host_url}/channel/#{self.ucid}" }
        else
          xml.element("name") { xml.text author }
          xml.element("uri") { xml.text "#{host_url}/channel/#{ucid}" }
        end
      end

      xml.element("content", type: "xhtml") do
        xml.element("div", xmlns: "http://www.w3.org/1999/xhtml") do
          xml.element("a", href: "#{host_url}/watch?#{query_params}") do
            xml.element("img", src: "#{host_url}/vi/#{self.id}/mqdefault.jpg")
          end

          xml.element("p", style: "word-break:break-word;white-space:pre-wrap") { xml.text html_to_content(self.description_html) }
        end
      end

      xml.element("published") { xml.text self.published.to_s("%Y-%m-%dT%H:%M:%S%:z") }

      xml.element("media:group") do
        xml.element("media:title") { xml.text self.title }
        xml.element("media:thumbnail", url: "#{host_url}/vi/#{self.id}/mqdefault.jpg",
          width: "320", height: "180")
        xml.element("media:description") { xml.text html_to_content(self.description_html) }
      end

      xml.element("media:community") do
        xml.element("media:statistics", views: self.views)
      end
    end
  end

  def to_xml(host_url, auto_generated, query_params, xml : XML::Builder | Nil = nil)
    if xml
      to_xml(host_url, auto_generated, query_params, xml)
    else
      XML.build do |json|
        to_xml(host_url, auto_generated, query_params, xml)
      end
    end
  end

  def to_json(locale, config, kemal_config, json : JSON::Builder)
    json.object do
      json.field "type", "video"
      json.field "title", self.title
      json.field "videoId", self.id

      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", "/channel/#{self.ucid}"

      json.field "videoThumbnails" do
        generate_thumbnails(json, self.id, config, kemal_config)
      end

      json.field "description", html_to_content(self.description_html)
      json.field "descriptionHtml", self.description_html

      json.field "viewCount", self.views
      json.field "published", self.published.to_unix
      json.field "publishedText", translate(locale, "`x` ago", recode_date(self.published, locale))
      json.field "lengthSeconds", self.length_seconds
      json.field "liveNow", self.live_now
      json.field "paid", self.paid
      json.field "premium", self.premium
    end
  end

  def to_json(locale, config, kemal_config, json : JSON::Builder | Nil = nil)
    if json
      to_json(locale, config, kemal_config, json)
    else
      JSON.build do |json|
        to_json(locale, config, kemal_config, json)
      end
    end
  end

  db_mapping({
    title:              String,
    id:                 String,
    author:             String,
    ucid:               String,
    published:          Time,
    views:              Int64,
    description_html:   String,
    length_seconds:     Int32,
    live_now:           Bool,
    paid:               Bool,
    premium:            Bool,
    premiere_timestamp: Time?,
  })
end

struct SearchPlaylistVideo
  db_mapping({
    title:          String,
    id:             String,
    length_seconds: Int32,
  })
end

struct SearchPlaylist
  def to_json(locale, config, kemal_config, json : JSON::Builder)
    json.object do
      json.field "type", "playlist"
      json.field "title", self.title
      json.field "playlistId", self.id
      json.field "playlistThumbnail", self.thumbnail

      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", "/channel/#{self.ucid}"

      json.field "videoCount", self.video_count
      json.field "videos" do
        json.array do
          self.videos.each do |video|
            json.object do
              json.field "title", video.title
              json.field "videoId", video.id
              json.field "lengthSeconds", video.length_seconds

              json.field "videoThumbnails" do
                generate_thumbnails(json, video.id, config, Kemal.config)
              end
            end
          end
        end
      end
    end
  end

  def to_json(locale, config, kemal_config, json : JSON::Builder | Nil = nil)
    if json
      to_json(locale, config, kemal_config, json)
    else
      JSON.build do |json|
        to_json(locale, config, kemal_config, json)
      end
    end
  end

  db_mapping({
    title:       String,
    id:          String,
    author:      String,
    ucid:        String,
    video_count: Int32,
    videos:      Array(SearchPlaylistVideo),
    thumbnail:   String?,
  })
end

struct SearchChannel
  def to_json(locale, config, kemal_config, json : JSON::Builder)
    json.object do
      json.field "type", "channel"
      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", "/channel/#{self.ucid}"

      json.field "authorThumbnails" do
        json.array do
          qualities = {32, 48, 76, 100, 176, 512}

          qualities.each do |quality|
            json.object do
              json.field "url", self.author_thumbnail.gsub(/=\d+/, "=s#{quality}")
              json.field "width", quality
              json.field "height", quality
            end
          end
        end
      end

      json.field "autoGenerated", self.auto_generated
      json.field "subCount", self.subscriber_count
      json.field "videoCount", self.video_count

      json.field "description", html_to_content(self.description_html)
      json.field "descriptionHtml", self.description_html
    end
  end

  def to_json(locale, config, kemal_config, json : JSON::Builder | Nil = nil)
    if json
      to_json(locale, config, kemal_config, json)
    else
      JSON.build do |json|
        to_json(locale, config, kemal_config, json)
      end
    end
  end

  db_mapping({
    author:           String,
    ucid:             String,
    author_thumbnail: String,
    subscriber_count: Int32,
    video_count:      Int32,
    description_html: String,
    auto_generated:   Bool,
  })
end

alias SearchItem = SearchVideo | SearchChannel | SearchPlaylist

def channel_search(query, page, channel)
  response = YT_POOL.client &.get("/channel/#{channel}?disable_polymer=1&hl=en&gl=US")
  document = XML.parse_html(response.body)
  canonical = document.xpath_node(%q(//link[@rel="canonical"]))

  if !canonical
    response = YT_POOL.client &.get("/c/#{channel}?disable_polymer=1&hl=en&gl=US")
    document = XML.parse_html(response.body)
    canonical = document.xpath_node(%q(//link[@rel="canonical"]))
  end

  if !canonical
    response = YT_POOL.client &.get("/user/#{channel}?disable_polymer=1&hl=en&gl=US")
    document = XML.parse_html(response.body)
    canonical = document.xpath_node(%q(//link[@rel="canonical"]))
  end

  if !canonical
    return 0, [] of SearchItem
  end

  ucid = canonical["href"].split("/")[-1]

  url = produce_channel_search_url(ucid, query, page)
  response = YT_POOL.client &.get(url)
  json = JSON.parse(response.body)

  if json["content_html"]? && !json["content_html"].as_s.empty?
    document = XML.parse_html(json["content_html"].as_s)
    nodeset = document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")]))

    count = nodeset.size
    items = extract_items(nodeset)
  else
    count = 0
    items = [] of SearchItem
  end

  return count, items
end

def search(query, page = 1, search_params = produce_search_params(content_type: "all"), region = nil)
  if query.empty?
    return {0, [] of SearchItem}
  end

  html = YT_POOL.client(region, &.get("/results?q=#{URI.encode_www_form(query)}&page=#{page}&sp=#{search_params}&hl=en&disable_polymer=1").body)
  if html.empty?
    return {0, [] of SearchItem}
  end

  html = XML.parse_html(html)
  nodeset = html.xpath_nodes(%q(//ol[@class="item-section"]/li))
  items = extract_items(nodeset)

  return {nodeset.size, items}
end

def produce_search_params(sort : String = "relevance", date : String = "", content_type : String = "",
                          duration : String = "", features : Array(String) = [] of String)
  object = {
    "1:varint"   => 0_i64,
    "2:embedded" => {} of String => Int64,
  }

  case sort
  when "relevance"
    object["1:varint"] = 0_i64
  when "rating"
    object["1:varint"] = 1_i64
  when "upload_date", "date"
    object["1:varint"] = 2_i64
  when "view_count", "views"
    object["1:varint"] = 3_i64
  else
    raise "No sort #{sort}"
  end

  case date
  when "hour"
    object["2:embedded"].as(Hash)["1:varint"] = 1_i64
  when "today"
    object["2:embedded"].as(Hash)["1:varint"] = 2_i64
  when "week"
    object["2:embedded"].as(Hash)["1:varint"] = 3_i64
  when "month"
    object["2:embedded"].as(Hash)["1:varint"] = 4_i64
  when "year"
    object["2:embedded"].as(Hash)["1:varint"] = 5_i64
  end

  case content_type
  when "video"
    object["2:embedded"].as(Hash)["2:varint"] = 1_i64
  when "channel"
    object["2:embedded"].as(Hash)["2:varint"] = 2_i64
  when "playlist"
    object["2:embedded"].as(Hash)["2:varint"] = 3_i64
  when "movie"
    object["2:embedded"].as(Hash)["2:varint"] = 4_i64
  when "show"
    object["2:embedded"].as(Hash)["2:varint"] = 5_i64
  when "all"
    #
  else
    object["2:embedded"].as(Hash)["2:varint"] = 1_i64
  end

  case duration
  when "short"
    object["2:embedded"].as(Hash)["3:varint"] = 1_i64
  when "long"
    object["2:embedded"].as(Hash)["3:varint"] = 2_i64
  end

  features.each do |feature|
    case feature
    when "hd"
      object["2:embedded"].as(Hash)["4:varint"] = 1_i64
    when "subtitles"
      object["2:embedded"].as(Hash)["5:varint"] = 1_i64
    when "creative_commons", "cc"
      object["2:embedded"].as(Hash)["6:varint"] = 1_i64
    when "3d"
      object["2:embedded"].as(Hash)["7:varint"] = 1_i64
    when "live", "livestream"
      object["2:embedded"].as(Hash)["8:varint"] = 1_i64
    when "purchased"
      object["2:embedded"].as(Hash)["9:varint"] = 1_i64
    when "4k"
      object["2:embedded"].as(Hash)["14:varint"] = 1_i64
    when "360"
      object["2:embedded"].as(Hash)["15:varint"] = 1_i64
    when "location"
      object["2:embedded"].as(Hash)["23:varint"] = 1_i64
    when "hdr"
      object["2:embedded"].as(Hash)["25:varint"] = 1_i64
    end
  end

  if object["2:embedded"].as(Hash).empty?
    object.delete("2:embedded")
  end

  params = object.try { |i| Protodec::Any.cast_json(object) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return params
end

def produce_channel_search_url(ucid, query, page)
  object = {
    "80226972:embedded" => {
      "2:string" => ucid,
      "3:base64" => {
        "2:string"  => "search",
        "6:varint"  => 2_i64,
        "7:varint"  => 1_i64,
        "12:varint" => 1_i64,
        "13:string" => "",
        "23:varint" => 0_i64,
        "15:string" => "#{page}",
      },
      "11:string" => query,
    },
  }

  continuation = object.try { |i| Protodec::Any.cast_json(object) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return "/browse_ajax?continuation=#{continuation}&gl=US&hl=en"
end

def process_search_query(query, page, user, region)
  if user
    user = user.as(User)
    view_name = "subscriptions_#{sha256(user.email)}"
  end

  channel = nil
  content_type = "all"
  date = ""
  duration = ""
  features = [] of String
  sort = "relevance"
  subscriptions = nil

  operators = query.split(" ").select { |a| a.match(/\w+:[\w,]+/) }
  operators.each do |operator|
    key, value = operator.downcase.split(":")

    case key
    when "channel", "user"
      channel = operator.split(":")[-1]
    when "content_type", "type"
      content_type = value
    when "date"
      date = value
    when "duration"
      duration = value
    when "feature", "features"
      features = value.split(",")
    when "sort"
      sort = value
    when "subscriptions"
      subscriptions = value == "true"
    else
      operators.delete(operator)
    end
  end

  search_query = (query.split(" ") - operators).join(" ")

  if channel
    count, items = channel_search(search_query, page, channel)
  elsif subscriptions
    if view_name
      items = PG_DB.query_all("SELECT id,title,published,updated,ucid,author,length_seconds FROM (
      SELECT *,
      to_tsvector(#{view_name}.title) ||
      to_tsvector(#{view_name}.author)
      as document
      FROM #{view_name}
      ) v_search WHERE v_search.document @@ plainto_tsquery($1) LIMIT 20 OFFSET $2;", search_query, (page - 1) * 20, as: ChannelVideo)
      count = items.size
    else
      items = [] of ChannelVideo
      count = 0
    end
  else
    search_params = produce_search_params(sort: sort, date: date, content_type: content_type,
      duration: duration, features: features)

    count, items = search(search_query, page, search_params, region).as(Tuple)
  end

  {search_query, count, items}
end
