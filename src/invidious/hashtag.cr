module Invidious::Hashtag
  extend self

  def fetch(hashtag : String, page : Int, region : String? = nil) : Array(SearchItem)
    cursor = (page - 1) * 60
    ctoken = generate_continuation(hashtag, cursor)

    client_config = YoutubeAPI::ClientConfig.new(region: region)
    response = YoutubeAPI.browse(continuation: ctoken, client_config: client_config)

    items, _ = extract_items(response)
    return items
  end

  def generate_continuation(hashtag : String, cursor : Int)
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

    continuation = object.try { |i| Protodec::Any.cast_json(i) }
      .try { |i| Protodec::Any.from_json(i) }
      .try { |i| Base64.urlsafe_encode(i) }
      .try { |i| URI.encode_www_form(i) }

    return continuation
  end
end
