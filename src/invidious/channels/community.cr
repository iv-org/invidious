# Fetches channel community posts for the initial page
def fetch_channel_community(ucid)
  initial_data = YoutubeAPI.browse(ucid, params: "Egljb21tdW5pdHk%3D")
  return extract_items(initial_data)
end

# Fetches the next batch of community posts after the given cursor
def fetch_channel_community(ucid, cursor)
  continuation = produce_channel_community_continuation(ucid, cursor)
  initial_data = YoutubeAPI.browse(continuation)
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
