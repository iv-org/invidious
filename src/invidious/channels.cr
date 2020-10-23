struct InvidiousChannel
  include DB::Serializable

  property id : String
  property author : String
  property updated : Time
  property deleted : Bool
  property subscribed : Time?
end

struct ChannelVideo
  include DB::Serializable

  property id : String
  property title : String
  property published : Time
  property updated : Time
  property ucid : String
  property author : String
  property length_seconds : Int32 = 0
  property live_now : Bool = false
  property premiere_timestamp : Time? = nil
  property views : Int64? = nil

  def to_json(locale, json : JSON::Builder)
    json.object do
      json.field "type", "shortVideo"

      json.field "title", self.title
      json.field "videoId", self.id
      json.field "videoThumbnails" do
        generate_thumbnails(json, self.id)
      end

      json.field "lengthSeconds", self.length_seconds

      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", "/channel/#{self.ucid}"
      json.field "published", self.published.to_unix
      json.field "publishedText", translate(locale, "`x` ago", recode_date(self.published, locale))

      json.field "viewCount", self.views
    end
  end

  def to_json(locale, json : JSON::Builder | Nil = nil)
    if json
      to_json(locale, json)
    else
      JSON.build do |json|
        to_json(locale, json)
      end
    end
  end

  def to_xml(locale, query_params, xml : XML::Builder)
    query_params["v"] = self.id

    xml.element("entry") do
      xml.element("id") { xml.text "yt:video:#{self.id}" }
      xml.element("yt:videoId") { xml.text self.id }
      xml.element("yt:channelId") { xml.text self.ucid }
      xml.element("title") { xml.text self.title }
      xml.element("link", rel: "alternate", href: "#{HOST_URL}/watch?#{query_params}")

      xml.element("author") do
        xml.element("name") { xml.text self.author }
        xml.element("uri") { xml.text "#{HOST_URL}/channel/#{self.ucid}" }
      end

      xml.element("content", type: "xhtml") do
        xml.element("div", xmlns: "http://www.w3.org/1999/xhtml") do
          xml.element("a", href: "#{HOST_URL}/watch?#{query_params}") do
            xml.element("img", src: "#{HOST_URL}/vi/#{self.id}/mqdefault.jpg")
          end
        end
      end

      xml.element("published") { xml.text self.published.to_s("%Y-%m-%dT%H:%M:%S%:z") }
      xml.element("updated") { xml.text self.updated.to_s("%Y-%m-%dT%H:%M:%S%:z") }

      xml.element("media:group") do
        xml.element("media:title") { xml.text self.title }
        xml.element("media:thumbnail", url: "#{HOST_URL}/vi/#{self.id}/mqdefault.jpg",
          width: "320", height: "180")
      end
    end
  end

  def to_xml(locale, xml : XML::Builder | Nil = nil)
    if xml
      to_xml(locale, xml)
    else
      XML.build do |xml|
        to_xml(locale, xml)
      end
    end
  end

  def to_tuple
    {% begin %}
      {
        {{*@type.instance_vars.map { |var| var.name }}}
      }
    {% end %}
  end
end

struct AboutRelatedChannel
  include DB::Serializable

  property ucid : String
  property author : String
  property author_url : String
  property author_thumbnail : String
end

# TODO: Refactor into either SearchChannel or InvidiousChannel
struct AboutChannel
  include DB::Serializable

  property ucid : String
  property author : String
  property auto_generated : Bool
  property author_url : String
  property author_thumbnail : String
  property banner : String?
  property description_html : String
  property paid : Bool
  property total_views : Int64
  property sub_count : Int32
  property joined : Time
  property is_family_friendly : Bool
  property allowed_regions : Array(String)
  property related_channels : Array(AboutRelatedChannel)
  property tabs : Array(String)
end

class ChannelRedirect < Exception
  property channel_id : String

  def initialize(@channel_id)
  end
end

def get_batch_channels(channels, db, refresh = false, pull_all_videos = true, max_threads = 10)
  finished_channel = Channel(String | Nil).new

  spawn do
    active_threads = 0
    active_channel = Channel(Nil).new

    channels.each do |ucid|
      if active_threads >= max_threads
        active_channel.receive
        active_threads -= 1
      end

      active_threads += 1
      spawn do
        begin
          get_channel(ucid, db, refresh, pull_all_videos)
          finished_channel.send(ucid)
        rescue ex
          finished_channel.send(nil)
        ensure
          active_channel.send(nil)
        end
      end
    end
  end

  final = [] of String
  channels.size.times do
    if ucid = finished_channel.receive
      final << ucid
    end
  end

  return final
end

def get_channel(id, db, refresh = true, pull_all_videos = true)
  if channel = db.query_one?("SELECT * FROM channels WHERE id = $1", id, as: InvidiousChannel)
    if refresh && Time.utc - channel.updated > 10.minutes
      channel = fetch_channel(id, db, pull_all_videos: pull_all_videos)
      channel_array = channel.to_a
      args = arg_array(channel_array)

      db.exec("INSERT INTO channels VALUES (#{args}) \
        ON CONFLICT (id) DO UPDATE SET author = $2, updated = $3", args: channel_array)
    end
  else
    channel = fetch_channel(id, db, pull_all_videos: pull_all_videos)
    channel_array = channel.to_a
    args = arg_array(channel_array)

    db.exec("INSERT INTO channels VALUES (#{args})", args: channel_array)
  end

  return channel
end

def fetch_channel(ucid, db, pull_all_videos = true, locale = nil)
  rss = YT_POOL.client &.get("/feeds/videos.xml?channel_id=#{ucid}").body
  rss = XML.parse_html(rss)

  author = rss.xpath_node(%q(//feed/title))
  if !author
    raise translate(locale, "Deleted or invalid channel")
  end
  author = author.content

  # Auto-generated channels
  # https://support.google.com/youtube/answer/2579942
  if author.ends_with?(" - Topic") ||
     {"Popular on YouTube", "Music", "Sports", "Gaming"}.includes? author
    auto_generated = true
  end

  page = 1

  response = get_channel_videos_response(ucid, page, auto_generated: auto_generated)

  videos = [] of SearchVideo
  begin
    initial_data = JSON.parse(response.body).as_a.find &.["response"]?
    raise "Could not extract JSON" if !initial_data
    videos = extract_videos(initial_data.as_h, author, ucid)
  rescue ex
    if response.body.includes?("To continue with your YouTube experience, please fill out the form below.") ||
       response.body.includes?("https://www.google.com/sorry/index")
      raise "Could not extract channel info. Instance is likely blocked."
    end
  end

  rss.xpath_nodes("//feed/entry").each do |entry|
    video_id = entry.xpath_node("videoid").not_nil!.content
    title = entry.xpath_node("title").not_nil!.content
    published = Time.parse_rfc3339(entry.xpath_node("published").not_nil!.content)
    updated = Time.parse_rfc3339(entry.xpath_node("updated").not_nil!.content)
    author = entry.xpath_node("author/name").not_nil!.content
    ucid = entry.xpath_node("channelid").not_nil!.content
    views = entry.xpath_node("group/community/statistics").try &.["views"]?.try &.to_i64?
    views ||= 0_i64

    channel_video = videos.select { |video| video.id == video_id }[0]?

    length_seconds = channel_video.try &.length_seconds
    length_seconds ||= 0

    live_now = channel_video.try &.live_now
    live_now ||= false

    premiere_timestamp = channel_video.try &.premiere_timestamp

    video = ChannelVideo.new({
      id:                 video_id,
      title:              title,
      published:          published,
      updated:            Time.utc,
      ucid:               ucid,
      author:             author,
      length_seconds:     length_seconds,
      live_now:           live_now,
      premiere_timestamp: premiere_timestamp,
      views:              views,
    })

    # We don't include the 'premiere_timestamp' here because channel pages don't include them,
    # meaning the above timestamp is always null
    was_insert = db.query_one("INSERT INTO channel_videos VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) \
      ON CONFLICT (id) DO UPDATE SET title = $2, published = $3, \
      updated = $4, ucid = $5, author = $6, length_seconds = $7, \
      live_now = $8, views = $10 returning (xmax=0) as was_insert", *video.to_tuple, as: Bool)

    db.exec("UPDATE users SET notifications = array_append(notifications, $1), \
      feed_needs_update = true WHERE $2 = ANY(subscriptions)", video.id, video.ucid) if was_insert
  end

  if pull_all_videos
    page += 1

    ids = [] of String

    loop do
      response = get_channel_videos_response(ucid, page, auto_generated: auto_generated)
      initial_data = JSON.parse(response.body).as_a.find &.["response"]?
      raise "Could not extract JSON" if !initial_data
      videos = extract_videos(initial_data.as_h, author, ucid)

      count = videos.size
      videos = videos.map { |video| ChannelVideo.new({
        id:                 video.id,
        title:              video.title,
        published:          video.published,
        updated:            Time.utc,
        ucid:               video.ucid,
        author:             video.author,
        length_seconds:     video.length_seconds,
        live_now:           video.live_now,
        premiere_timestamp: video.premiere_timestamp,
        views:              video.views,
      }) }

      videos.each do |video|
        ids << video.id

        # We are notified of Red videos elsewhere (PubSub), which includes a correct published date,
        # so since they don't provide a published date here we can safely ignore them.
        if Time.utc - video.published > 1.minute
          was_insert = db.query_one("INSERT INTO channel_videos VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) \
            ON CONFLICT (id) DO UPDATE SET title = $2, published = $3, \
            updated = $4, ucid = $5, author = $6, length_seconds = $7, \
            live_now = $8, views = $10 returning (xmax=0) as was_insert", *video.to_tuple, as: Bool)

          db.exec("UPDATE users SET notifications = array_append(notifications, $1), \
            feed_needs_update = true WHERE $2 = ANY(subscriptions)", video.id, video.ucid) if was_insert
        end
      end

      break if count < 25
      page += 1
    end
  end

  channel = InvidiousChannel.new({
    id:         ucid,
    author:     author,
    updated:    Time.utc,
    deleted:    false,
    subscribed: nil,
  })

  return channel
end

def fetch_channel_playlists(ucid, author, auto_generated, continuation, sort_by)
  if continuation || auto_generated
    url = produce_channel_playlists_url(ucid, continuation, sort_by, auto_generated)

    response = YT_POOL.client &.get(url)

    continuation = response.body.match(/"continuation":"(?<continuation>[^"]+)"/).try &.["continuation"]?
    initial_data = JSON.parse(response.body).as_a.find(&.["response"]?).try &.as_h
  else
    url = "/channel/#{ucid}/playlists?flow=list&view=1"

    case sort_by
    when "last", "last_added"
      #
    when "oldest", "oldest_created"
      url += "&sort=da"
    when "newest", "newest_created"
      url += "&sort=dd"
    else nil # Ignore
    end

    response = YT_POOL.client &.get(url)
    continuation = response.body.match(/"continuation":"(?<continuation>[^"]+)"/).try &.["continuation"]?
    initial_data = extract_initial_data(response.body)
  end

  return [] of SearchItem, nil if !initial_data
  items = extract_items(initial_data)
  continuation = extract_channel_playlists_cursor(continuation, auto_generated) if continuation

  return items, continuation
end

def produce_channel_videos_url(ucid, page = 1, auto_generated = nil, sort_by = "newest", v2 = false)
  object = {
    "80226972:embedded" => {
      "2:string" => ucid,
      "3:base64" => {
        "2:string"  => "videos",
        "6:varint"  => 2_i64,
        "7:varint"  => 1_i64,
        "12:varint" => 1_i64,
        "13:string" => "",
        "23:varint" => 0_i64,
      },
    },
  }

  if !v2
    if auto_generated
      seed = Time.unix(1525757349)
      until seed >= Time.utc
        seed += 1.month
      end
      timestamp = seed - (page - 1).months

      object["80226972:embedded"]["3:base64"].as(Hash)["4:varint"] = 0x36_i64
      object["80226972:embedded"]["3:base64"].as(Hash)["15:string"] = "#{timestamp.to_unix}"
    else
      object["80226972:embedded"]["3:base64"].as(Hash)["4:varint"] = 0_i64
      object["80226972:embedded"]["3:base64"].as(Hash)["15:string"] = "#{page}"
    end
  else
    object["80226972:embedded"]["3:base64"].as(Hash)["4:varint"] = 0_i64

    object["80226972:embedded"]["3:base64"].as(Hash)["61:string"] = Base64.urlsafe_encode(Protodec::Any.from_json(Protodec::Any.cast_json({
      "1:string" => Base64.urlsafe_encode(Protodec::Any.from_json(Protodec::Any.cast_json({
        "1:varint" => 30_i64 * (page - 1),
      }))),
    })))
  end

  case sort_by
  when "newest"
  when "popular"
    object["80226972:embedded"]["3:base64"].as(Hash)["3:varint"] = 0x01_i64
  when "oldest"
    object["80226972:embedded"]["3:base64"].as(Hash)["3:varint"] = 0x02_i64
  else nil # Ignore
  end

  object["80226972:embedded"]["3:string"] = Base64.urlsafe_encode(Protodec::Any.from_json(Protodec::Any.cast_json(object["80226972:embedded"]["3:base64"])))
  object["80226972:embedded"].delete("3:base64")

  continuation = object.try { |i| Protodec::Any.cast_json(object) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return "/browse_ajax?continuation=#{continuation}&gl=US&hl=en"
end

def produce_channel_playlists_url(ucid, cursor, sort = "newest", auto_generated = false)
  object = {
    "80226972:embedded" => {
      "2:string" => ucid,
      "3:base64" => {
        "2:string"  => "playlists",
        "6:varint"  => 2_i64,
        "7:varint"  => 1_i64,
        "12:varint" => 1_i64,
        "13:string" => "",
        "23:varint" => 0_i64,
      },
    },
  }

  if cursor
    cursor = Base64.urlsafe_encode(cursor, false) if !auto_generated
    object["80226972:embedded"]["3:base64"].as(Hash)["15:string"] = cursor
  end

  if auto_generated
    object["80226972:embedded"]["3:base64"].as(Hash)["4:varint"] = 0x32_i64
  else
    object["80226972:embedded"]["3:base64"].as(Hash)["4:varint"] = 1_i64
    case sort
    when "oldest", "oldest_created"
      object["80226972:embedded"]["3:base64"].as(Hash)["3:varint"] = 2_i64
    when "newest", "newest_created"
      object["80226972:embedded"]["3:base64"].as(Hash)["3:varint"] = 3_i64
    when "last", "last_added"
      object["80226972:embedded"]["3:base64"].as(Hash)["3:varint"] = 4_i64
    else nil # Ignore
    end
  end

  object["80226972:embedded"]["3:string"] = Base64.urlsafe_encode(Protodec::Any.from_json(Protodec::Any.cast_json(object["80226972:embedded"]["3:base64"])))
  object["80226972:embedded"].delete("3:base64")

  continuation = object.try { |i| Protodec::Any.cast_json(object) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return "/browse_ajax?continuation=#{continuation}&gl=US&hl=en"
end

def extract_channel_playlists_cursor(cursor, auto_generated)
  cursor = URI.decode_www_form(cursor)
    .try { |i| Base64.decode(i) }
    .try { |i| IO::Memory.new(i) }
    .try { |i| Protodec::Any.parse(i) }
    .try { |i| i["80226972:0:embedded"]["3:1:base64"].as_h.find { |k, v| k.starts_with? "15:" } }
    .try &.[1]

  if cursor.try &.as_h?
    cursor = cursor.try { |i| Protodec::Any.cast_json(i.as_h) }
      .try { |i| Protodec::Any.from_json(i) }
      .try { |i| Base64.urlsafe_encode(i) }
      .try { |i| URI.encode_www_form(i) } || ""
  else
    cursor = cursor.try &.as_s || ""
  end

  if !auto_generated
    cursor = URI.decode_www_form(cursor)
      .try { |i| Base64.decode_string(i) }
  end

  return cursor
end

# TODO: Add "sort_by"
def fetch_channel_community(ucid, continuation, locale, format, thin_mode)
  response = YT_POOL.client &.get("/channel/#{ucid}/community?gl=US&hl=en")
  if response.status_code != 200
    response = YT_POOL.client &.get("/user/#{ucid}/community?gl=US&hl=en")
  end

  if response.status_code != 200
    error_message = translate(locale, "This channel does not exist.")
    raise error_message
  end

  ucid = response.body.match(/https:\/\/www.youtube.com\/channel\/(?<ucid>UC[a-zA-Z0-9_-]{22})/).not_nil!["ucid"]

  if !continuation || continuation.empty?
    initial_data = extract_initial_data(response.body)
    body = initial_data["contents"]?.try &.["twoColumnBrowseResultsRenderer"]["tabs"].as_a.select { |tab| tab["tabRenderer"]?.try &.["selected"].as_bool.== true }[0]?

    if !body
      raise "Could not extract community tab."
    end

    body = body["tabRenderer"]["content"]["sectionListRenderer"]["contents"][0]["itemSectionRenderer"]
  else
    continuation = produce_channel_community_continuation(ucid, continuation)

    headers = HTTP::Headers.new
    headers["cookie"] = response.cookies.add_request_headers(headers)["cookie"]

    session_token = response.body.match(/"XSRF_TOKEN":"(?<session_token>[^"]+)"/).try &.["session_token"]? || ""
    post_req = {
      session_token: session_token,
    }

    response = YT_POOL.client &.post("/comment_service_ajax?action_get_comments=1&ctoken=#{continuation}&continuation=#{continuation}&hl=en&gl=US", headers, form: post_req)
    body = JSON.parse(response.body)

    body = body["response"]["continuationContents"]["itemSectionContinuation"]? ||
           body["response"]["continuationContents"]["backstageCommentsContinuation"]?

    if !body
      raise "Could not extract continuation."
    end
  end

  continuation = body["continuations"]?.try &.[0]["nextContinuationData"]["continuation"].as_s
  posts = body["contents"].as_a

  if message = posts[0]["messageRenderer"]?
    error_message = (message["text"]["simpleText"]? ||
                     message["text"]["runs"]?.try &.[0]?.try &.["text"]?)
      .try &.as_s || ""
    raise error_message
  end

  response = JSON.build do |json|
    json.object do
      json.field "authorId", ucid
      json.field "comments" do
        json.array do
          posts.each do |post|
            comments = post["backstagePostThreadRenderer"]?.try &.["comments"]? ||
                       post["backstageCommentsContinuation"]?

            post = post["backstagePostThreadRenderer"]?.try &.["post"]["backstagePostRenderer"]? ||
                   post["commentThreadRenderer"]?.try &.["comment"]["commentRenderer"]?

            next if !post

            content_html = post["contentText"]?.try { |t| parse_content(t) } || ""
            author = post["authorText"]?.try &.["simpleText"]? || ""

            json.object do
              json.field "author", author
              json.field "authorThumbnails" do
                json.array do
                  qualities = {32, 48, 76, 100, 176, 512}
                  author_thumbnail = post["authorThumbnail"]["thumbnails"].as_a[0]["url"].as_s

                  qualities.each do |quality|
                    json.object do
                      json.field "url", author_thumbnail.gsub(/s\d+-/, "s#{quality}-")
                      json.field "width", quality
                      json.field "height", quality
                    end
                  end
                end
              end

              if post["authorEndpoint"]?
                json.field "authorId", post["authorEndpoint"]["browseEndpoint"]["browseId"]
                json.field "authorUrl", post["authorEndpoint"]["commandMetadata"]["webCommandMetadata"]["url"].as_s
              else
                json.field "authorId", ""
                json.field "authorUrl", ""
              end

              published_text = post["publishedTimeText"]["runs"][0]["text"].as_s
              published = decode_date(published_text.rchop(" (edited)"))

              if published_text.includes?(" (edited)")
                json.field "isEdited", true
              else
                json.field "isEdited", false
              end

              like_count = post["actionButtons"]["commentActionButtonsRenderer"]["likeButton"]["toggleButtonRenderer"]["accessibilityData"]["accessibilityData"]["label"]
                .try &.as_s.gsub(/\D/, "").to_i? || 0

              json.field "content", html_to_content(content_html)
              json.field "contentHtml", content_html

              json.field "published", published.to_unix
              json.field "publishedText", translate(locale, "`x` ago", recode_date(published, locale))

              json.field "likeCount", like_count
              json.field "commentId", post["postId"]? || post["commentId"]? || ""
              json.field "authorIsChannelOwner", post["authorEndpoint"]["browseEndpoint"]["browseId"] == ucid

              if attachment = post["backstageAttachment"]?
                json.field "attachment" do
                  json.object do
                    case attachment.as_h
                    when .has_key?("videoRenderer")
                      attachment = attachment["videoRenderer"]
                      json.field "type", "video"

                      if !attachment["videoId"]?
                        error_message = (attachment["title"]["simpleText"]? ||
                                         attachment["title"]["runs"]?.try &.[0]?.try &.["text"]?)

                        json.field "error", error_message
                      else
                        video_id = attachment["videoId"].as_s

                        json.field "title", attachment["title"]["simpleText"].as_s
                        json.field "videoId", video_id
                        json.field "videoThumbnails" do
                          generate_thumbnails(json, video_id)
                        end

                        json.field "lengthSeconds", decode_length_seconds(attachment["lengthText"]["simpleText"].as_s)

                        author_info = attachment["ownerText"]["runs"][0].as_h

                        json.field "author", author_info["text"].as_s
                        json.field "authorId", author_info["navigationEndpoint"]["browseEndpoint"]["browseId"]
                        json.field "authorUrl", author_info["navigationEndpoint"]["commandMetadata"]["webCommandMetadata"]["url"]

                        # TODO: json.field "authorThumbnails", "channelThumbnailSupportedRenderers"
                        # TODO: json.field "authorVerified", "ownerBadges"

                        published = decode_date(attachment["publishedTimeText"]["simpleText"].as_s)

                        json.field "published", published.to_unix
                        json.field "publishedText", translate(locale, "`x` ago", recode_date(published, locale))

                        view_count = attachment["viewCountText"]["simpleText"].as_s.gsub(/\D/, "").to_i64? || 0_i64

                        json.field "viewCount", view_count
                        json.field "viewCountText", translate(locale, "`x` views", number_to_short_text(view_count))
                      end
                    when .has_key?("backstageImageRenderer")
                      attachment = attachment["backstageImageRenderer"]
                      json.field "type", "image"

                      json.field "imageThumbnails" do
                        json.array do
                          thumbnail = attachment["image"]["thumbnails"][0].as_h
                          width = thumbnail["width"].as_i
                          height = thumbnail["height"].as_i
                          aspect_ratio = (width.to_f / height.to_f)
                          url = thumbnail["url"].as_s.gsub(/=w\d+-h\d+(-p)?(-nd)?(-df)?(-rwa)?/, "=s640")

                          qualities = {320, 560, 640, 1280, 2000}

                          qualities.each do |quality|
                            json.object do
                              json.field "url", url.gsub(/=s\d+/, "=s#{quality}")
                              json.field "width", quality
                              json.field "height", (quality / aspect_ratio).ceil.to_i
                            end
                          end
                        end
                      end
                      # TODO
                      # when .has_key?("pollRenderer")
                      #   attachment = attachment["pollRenderer"]
                      #   json.field "type", "poll"
                    else
                      json.field "type", "unknown"
                      json.field "error", "Unrecognized attachment type."
                    end
                  end
                end
              end

              if comments && (reply_count = (comments["backstageCommentsRenderer"]["moreText"]["simpleText"]? ||
                                             comments["backstageCommentsRenderer"]["moreText"]["runs"]?.try &.[0]?.try &.["text"]?)
                   .try &.as_s.gsub(/\D/, "").to_i?)
                continuation = comments["backstageCommentsRenderer"]["continuations"]?.try &.as_a[0]["nextContinuationData"]["continuation"].as_s
                continuation ||= ""

                json.field "replies" do
                  json.object do
                    json.field "replyCount", reply_count
                    json.field "continuation", extract_channel_community_cursor(continuation)
                  end
                end
              end
            end
          end
        end
      end

      if body["continuations"]?
        continuation = body["continuations"][0]["nextContinuationData"]["continuation"].as_s
        json.field "continuation", extract_channel_community_cursor(continuation)
      end
    end
  end

  if format == "html"
    response = JSON.parse(response)
    content_html = template_youtube_comments(response, locale, thin_mode)

    response = JSON.build do |json|
      json.object do
        json.field "contentHtml", content_html
      end
    end
  end

  return response
end

def produce_channel_community_continuation(ucid, cursor)
  object = {
    "80226972:embedded" => {
      "2:string" => ucid,
      "3:string" => cursor || "",
    },
  }

  continuation = object.try { |i| Protodec::Any.cast_json(object) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return continuation
end

def extract_channel_community_cursor(continuation)
  object = URI.decode_www_form(continuation)
    .try { |i| Base64.decode(i) }
    .try { |i| IO::Memory.new(i) }
    .try { |i| Protodec::Any.parse(i) }
    .try { |i| i["80226972:0:embedded"]["3:1:base64"].as_h }

  if object["53:2:embedded"]?.try &.["3:0:embedded"]?
    object["53:2:embedded"]["3:0:embedded"]["2:0:string"] = object["53:2:embedded"]["3:0:embedded"]
      .try { |i| i["2:0:base64"].as_h }
      .try { |i| Protodec::Any.cast_json(i) }
      .try { |i| Protodec::Any.from_json(i) }
      .try { |i| Base64.urlsafe_encode(i, padding: false) }

    object["53:2:embedded"]["3:0:embedded"].as_h.delete("2:0:base64")
  end

  cursor = Protodec::Any.cast_json(object)
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }

  cursor
end

INITDATA_PREQUERY = "window[\"ytInitialData\"] = {"

def get_about_info(ucid, locale)
  about = YT_POOL.client &.get("/channel/#{ucid}/about?gl=US&hl=en")
  if about.status_code != 200
    about = YT_POOL.client &.get("/user/#{ucid}/about?gl=US&hl=en")
  end

  if md = about.headers["location"]?.try &.match(/\/channel\/(?<ucid>UC[a-zA-Z0-9_-]{22})/)
    raise ChannelRedirect.new(channel_id: md["ucid"])
  end

  if about.status_code != 200
    error_message = translate(locale, "This channel does not exist.")
    raise error_message
  end

  initdata_pre = about.body.index(INITDATA_PREQUERY)
  initdata_post = initdata_pre.nil? ? nil : about.body.index("};", initdata_pre)
  if initdata_post.nil?
    about = XML.parse_html(about.body)
    error_message = about.xpath_node(%q(//div[@class="yt-alert-content"])).try &.content.strip
    error_message ||= translate(locale, "Could not get channel info.")
    raise error_message
  end
  initdata_pre = initdata_pre.not_nil! + INITDATA_PREQUERY.size - 1

  initdata = JSON.parse(about.body[initdata_pre, initdata_post - initdata_pre + 1])
  about = XML.parse_html(about.body)

  if about.xpath_node(%q(//div[contains(@class, "channel-empty-message")]))
    error_message = translate(locale, "This channel does not exist.")
    raise error_message
  end

  author = about.xpath_node(%q(//meta[@name="title"])).not_nil!["content"]
  author_url = about.xpath_node(%q(//link[@rel="canonical"])).not_nil!["href"]
  author_thumbnail = about.xpath_node(%q(//link[@rel="image_src"])).not_nil!["href"]

  ucid = about.xpath_node(%q(//meta[@itemprop="channelId"])).not_nil!["content"]

  # Raises a KeyError on failure.
  banners = initdata["header"]["c4TabbedHeaderRenderer"]?.try &.["banner"]?.try &.["thumbnails"]?
  banner = banners.try &.[-1]?.try &.["url"].as_s?

  # if banner.includes? "channels/c4/default_banner"
  #  banner = nil
  # end

  description = initdata["metadata"]["channelMetadataRenderer"]?.try &.["description"]?.try &.as_s? || ""
  description_html = HTML.escape(description).gsub("\n", "<br>")

  paid = about.xpath_node(%q(//meta[@itemprop="paid"])).not_nil!["content"] == "True"
  is_family_friendly = about.xpath_node(%q(//meta[@itemprop="isFamilyFriendly"])).not_nil!["content"] == "True"
  allowed_regions = about.xpath_node(%q(//meta[@itemprop="regionsAllowed"])).not_nil!["content"].split(",")

  related_channels = initdata["contents"]["twoColumnBrowseResultsRenderer"]
    .["secondaryContents"]?.try &.["browseSecondaryContentsRenderer"]["contents"][0]?
    .try &.["verticalChannelSectionRenderer"]?.try &.["items"]?.try &.as_a.map do |node|
      renderer = node["miniChannelRenderer"]?
      related_id = renderer.try &.["channelId"]?.try &.as_s?
      related_id ||= ""

      related_title = renderer.try &.["title"]?.try &.["simpleText"]?.try &.as_s?
      related_title ||= ""

      related_author_url = renderer.try &.["navigationEndpoint"]?.try &.["commandMetadata"]?.try &.["webCommandMetadata"]?
        .try &.["url"]?.try &.as_s?
      related_author_url ||= ""

      related_author_thumbnails = renderer.try &.["thumbnail"]?.try &.["thumbnails"]?.try &.as_a?
      related_author_thumbnails ||= [] of JSON::Any

      related_author_thumbnail = ""
      if related_author_thumbnails.size > 0
        related_author_thumbnail = related_author_thumbnails[-1]["url"]?.try &.as_s?
        related_author_thumbnail ||= ""
      end

      AboutRelatedChannel.new({
        ucid:             related_id,
        author:           related_title,
        author_url:       related_author_url,
        author_thumbnail: related_author_thumbnail,
      })
    end
  related_channels ||= [] of AboutRelatedChannel

  total_views = 0_i64
  joined = Time.unix(0)
  tabs = [] of String
  auto_generated = false

  tabs_json = initdata["contents"]["twoColumnBrowseResultsRenderer"]["tabs"]?.try &.as_a?
  if !tabs_json.nil?
    # Retrieve information from the tabs array. The index we are looking for varies between channels.
    tabs_json.each do |node|
      # Try to find the about section which is located in only one of the tabs.
      channel_about_meta = node["tabRenderer"]?.try &.["content"]?.try &.["sectionListRenderer"]?
        .try &.["contents"]?.try &.[0]?.try &.["itemSectionRenderer"]?.try &.["contents"]?
          .try &.[0]?.try &.["channelAboutFullMetadataRenderer"]?

      if !channel_about_meta.nil?
        total_views = channel_about_meta["viewCountText"]?.try &.["simpleText"]?.try &.as_s.gsub(/\D/, "").to_i64? || 0_i64

        # The joined text is split to several sub strings. The reduce joins those strings before parsing the date.
        joined = channel_about_meta["joinedDateText"]?.try &.["runs"]?.try &.as_a.reduce("") { |acc, node| acc + node["text"].as_s }
          .try { |text| Time.parse(text, "Joined %b %-d, %Y", Time::Location.local) } || Time.unix(0)

        # Auto-generated channels
        # https://support.google.com/youtube/answer/2579942
        # For auto-generated channels, channel_about_meta only has ["description"]["simpleText"] and ["primaryLinks"][0]["title"]["simpleText"]
        if (channel_about_meta["primaryLinks"]?.try &.size || 0) == 1 && (channel_about_meta["primaryLinks"][0]?)
          (channel_about_meta["primaryLinks"][0]["title"]?.try &.["simpleText"]?.try &.as_s? || "") == "Auto-generated by YouTube"
          auto_generated = true
        end
      end
    end
    tabs = tabs_json.reject { |node| node["tabRenderer"]?.nil? }.map { |node| node["tabRenderer"]["title"].as_s.downcase }
  end

  sub_count = initdata["header"]["c4TabbedHeaderRenderer"]?.try &.["subscriberCountText"]?.try &.["simpleText"]?.try &.as_s?
    .try { |text| short_text_to_number(text.split(" ")[0]) } || 0

  AboutChannel.new({
    ucid:               ucid,
    author:             author,
    auto_generated:     auto_generated,
    author_url:         author_url,
    author_thumbnail:   author_thumbnail,
    banner:             banner,
    description_html:   description_html,
    paid:               paid,
    total_views:        total_views,
    sub_count:          sub_count,
    joined:             joined,
    is_family_friendly: is_family_friendly,
    allowed_regions:    allowed_regions,
    related_channels:   related_channels,
    tabs:               tabs,
  })
end

def get_channel_videos_response(ucid, page = 1, auto_generated = nil, sort_by = "newest")
  url = produce_channel_videos_url(ucid, page, auto_generated: auto_generated, sort_by: sort_by, v2: true)
  return YT_POOL.client &.get(url)
end

def get_60_videos(ucid, author, page, auto_generated, sort_by = "newest")
  videos = [] of SearchVideo

  2.times do |i|
    response = get_channel_videos_response(ucid, page * 2 + (i - 1), auto_generated: auto_generated, sort_by: sort_by)
    initial_data = JSON.parse(response.body).as_a.find &.["response"]?
    break if !initial_data
    videos.concat extract_videos(initial_data.as_h, author, ucid)
  end

  return videos.size, videos
end

def get_latest_videos(ucid)
  response = get_channel_videos_response(ucid, 1)
  initial_data = JSON.parse(response.body).as_a.find &.["response"]?
  return [] of SearchVideo if !initial_data
  author = initial_data["response"]?.try &.["metadata"]?.try &.["channelMetadataRenderer"]?.try &.["title"]?.try &.as_s
  items = extract_videos(initial_data.as_h, author, ucid)

  return items
end
