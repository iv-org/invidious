module Invidious::Hashtag
  extend self

  struct HashtagPage
    include DB::Serializable

    property videos : Array(SearchItem) | Array(Video)
    property header : HashtagHeader?
    property has_next_continuation : Bool

    def to_json(locale : String?, json : JSON::Builder)
      json.object do
        json.field "type", "hashtag"
        if self.header != nil
          json.field "header" do
            self.header.to_json(json)
          end
        end
        json.field "results" do
          json.array do
            self.videos.each do |item|
              item.to_json(locale, json)
            end
          end
        end
        json.field "hasNextPage", self.has_next_continuation
      end
    end

    # TODO: remove the locale and follow the crystal convention
    def to_json(locale : String?, _json : Nil)
      JSON.build do |json|
        to_json(locale, json)
      end
    end

    def to_json(json : JSON::Builder)
      to_json(nil, json)
    end
  end

  struct HashtagHeader
    include DB::Serializable

    property tag : String
    property channel_count : Int64
    property video_count : Int64

    def to_json(json : JSON::Builder)
      json.object do
        json.field "hashtag", self.tag
        json.field "channelCount", self.channel_count
        json.field "videoCount", self.video_count
      end
    end

    def to_json(_json : Nil)
      JSON.build do |json|
        to_json(json)
      end
    end
  end

  def fetch(hashtag : String, page : Int, region : String? = nil) : HashtagPage
    cursor = (page - 1) * 60
    header = nil
    client_config = YoutubeAPI::ClientConfig.new(region: region)
    item = generate_continuation(hashtag, cursor)
    # item is a ctoken
    if cursor > 0
      response = YoutubeAPI.browse(continuation: item, client_config: client_config)
    else
      # item browses the first page (including metadata)
      response = YoutubeAPI.browse("FEhashtag", params: item, client_config: client_config)
      if item_contents = response.dig?("header", "hashtagHeaderRenderer")
        header = parse_hashtag_renderer(item_contents)
      end
    end

    items, next_continuation = extract_items(response)
    return HashtagPage.new({
      videos:                items,
      header:                header,
      has_next_continuation: next_continuation != nil,
    })
  end

  def generate_continuation(hashtag : String, cursor : Int)
    object = {
      "93:2:embedded" => {
        "1:string" => hashtag,
        "2:varint" => 0_i64,
        "3:varint" => 1_i64,
      },
    }
    if cursor > 0
      object = {
        "80226972:embedded" => {
          "2:string" => "FEhashtag",
          "3:base64" => {
            "1:varint"  => 60_i64, # result count
            "15:base64" => {
              "1:varint" => cursor.to_i64,
              "2:varint" => 0_i64,
            },
            "93:2:embedded" => {
              "1:string" => hashtag,
              "2:varint" => 0_i64,
              "3:varint" => 1_i64,
            },
          },
          "35:string" => "browse-feedFEhashtag",
        },
      }
    end

    return object.try { |i| Protodec::Any.cast_json(i) }
      .try { |i| Protodec::Any.from_json(i) }
      .try { |i| Base64.urlsafe_encode(i) }
      .try { |i| URI.encode_www_form(i) }
  end

  def parse_hashtag_renderer(item_contents)
    info = extract_text(item_contents.dig?("hashtagInfoText")) || ""

    regex_match = /(?<videos>\d+\S)\D+(?<channels>\d+\S)/.match(info)

    hashtag = extract_text(item_contents.dig?("hashtag")) || ""
    videos = short_text_to_number(regex_match.try &.["videos"]?.try &.to_s || "0")
    channels = short_text_to_number(regex_match.try &.["channels"]?.try &.to_s || "0")

    return HashtagHeader.new({
      tag:           hashtag,
      channel_count: channels,
      video_count:   videos,
    })
  end
end
