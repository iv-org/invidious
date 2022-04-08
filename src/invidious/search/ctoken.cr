def produce_channel_search_continuation(ucid, query, page)
  if page <= 1
    idx = 0_i64
  else
    idx = 30_i64 * (page - 1)
  end

  object = {
    "80226972:embedded" => {
      "2:string" => ucid,
      "3:base64" => {
        "2:string"  => "search",
        "6:varint"  => 1_i64,
        "7:varint"  => 1_i64,
        "12:varint" => 1_i64,
        "15:base64" => {
          "3:varint" => idx,
        },
        "23:varint" => 0_i64,
      },
      "11:string" => query,
      "35:string" => "browse-feed#{ucid}search",
    },
  }

  continuation = object.try { |i| Protodec::Any.cast_json(i) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return continuation
end
