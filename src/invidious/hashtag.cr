module Invidious::Hashtag
  extend self

  def fetch(hashtag : String, page : Int, region : String? = nil) : Array(SearchItem)
    cursor = (page - 1) * 60
    ctoken = generate_continuation(hashtag, cursor)

    client_config = YoutubeAPI::ClientConfig.new(region: region)
    response = YoutubeAPI.browse(continuation: ctoken, client_config: client_config)

    return extract_items(response)
  end

  def generate_continuation(hashtag : String, cursor : Int)
    object = {
      "80226972:embedded" => {
        "2:string" => "FEhashtag",
        "3:base64" => {
          "1:varint" => cursor.to_i64,
        },
        "7:base64" => {
          "325477796:embedded" => {
            "1:embedded" => {
              "2:0:embedded" => {
                "2:string"  => '#' + hashtag,
                "4:varint"  => 0_i64,
                "11:string" => "",
              },
              "4:string" => "browse-feedFEhashtag",
            },
            "2:string" => hashtag,
          },
        },
      },
    }

    continuation = object.try { |i| Protodec::Any.cast_json(i) }
      .try { |i| Protodec::Any.from_json(i) }
      .try { |i| Base64.urlsafe_encode(i) }
      .try { |i| URI.encode_www_form(i) }

    return continuation
  end
end
