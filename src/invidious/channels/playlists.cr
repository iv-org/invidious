def fetch_channel_playlists(ucid, author, continuation, sort_by)
  if continuation
    initial_data = YoutubeAPI.browse(continuation)
  else
    params =
      case sort_by
      when "last", "last_added"
        # Equivalent to "&sort=lad"
        # {"2:string": "playlists", "3:varint": 4, "4:varint": 1, "6:varint": 1}
        "EglwbGF5bGlzdHMYBCABMAE%3D"
      when "oldest", "oldest_created"
        # formerly "&sort=da"
        # Not available anymore :c or maybe ??
        # {"2:string": "playlists", "3:varint": 2, "4:varint": 1, "6:varint": 1}
        "EglwbGF5bGlzdHMYAiABMAE%3D"
        # {"2:string": "playlists", "3:varint": 1, "4:varint": 1, "6:varint": 1}
        # "EglwbGF5bGlzdHMYASABMAE%3D"
      when "newest", "newest_created"
        # Formerly "&sort=dd"
        # {"2:string": "playlists", "3:varint": 3, "4:varint": 1, "6:varint": 1}
        "EglwbGF5bGlzdHMYAyABMAE%3D"
      end

    initial_data = YoutubeAPI.browse(ucid, params: params || "")
  end

  return extract_items(initial_data, author, ucid)
end

def fetch_channel_podcasts(ucid, author, continuation)
  if continuation
    initial_data = YoutubeAPI.browse(continuation)
  else
    initial_data = YoutubeAPI.browse(ucid, params: "Eghwb2RjYXN0c_IGBQoDugEA")
  end
  return extract_items(initial_data, author, ucid)
end

def fetch_channel_releases(ucid, author, continuation)
  if continuation
    initial_data = YoutubeAPI.browse(continuation)
  else
    initial_data = YoutubeAPI.browse(ucid, params: "EghyZWxlYXNlc_IGBQoDsgEA")
  end
  return extract_items(initial_data, author, ucid)
end
