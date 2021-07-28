# Fetches channel community posts for the initial page
def fetch_channel_community(ucid)
  initial_data = YoutubeAPI.browse(ucid, params: "Egljb21tdW5pdHk%3D")
  continuation_token = fetch_continuation_token(initial_data)
  cursor = continuation_token ? extract_channel_community_cursor(continuation_token) : nil

  return extract_items(initial_data), cursor
end

# Fetches the next batch of community posts after the given cursor
def fetch_channel_community(ucid, cursor, skip_full_page_check = false)
  continuation = produce_channel_community_continuation(ucid, cursor)
  initial_data = YoutubeAPI.browse(continuation)

  continuation_token = fetch_continuation_token(initial_data)
  cursor = continuation_token ? extract_channel_community_cursor(continuation_token) : nil
  items = extract_items(initial_data)

  if skip_full_page_check
  else
    # We want at least four items per page
    until items.size >= 4 || !cursor
      more_items, cursor = fetch_channel_community(ucid, cursor, skip_full_page_check = true)
      items = items + more_items
    end
  end

  return items, cursor
end

def produce_channel_community_continuation(ucid, cursor)
  object = {
    "80226972:embedded" => {
      "2:string"  => ucid,
      "3:string"  => cursor || "",
      "35:string" => "backstage-item-section",
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

  cursor = Protodec::Any.cast_json(object)
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }

  cursor
end
