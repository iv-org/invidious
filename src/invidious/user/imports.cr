require "csv"

struct Invidious::User
  module Import
    extend self

    # Parse a youtube CSV subscription file
    def parse_subscription_export_csv(csv_content : String)
      rows = CSV.new(csv_content.strip('\n'), headers: true)
      subscriptions = Array(String).new

      # Counter to limit the amount of imports.
      # This is intended to prevent DoS.
      row_counter = 0

      rows.each do |row|
        # Limit to 1200
        row_counter += 1
        break if row_counter > 1_200

        # Channel ID is the first column in the csv export we can't use the header
        # name, because the header name is localized depending on the
        # language the user has set on their account
        channel_id = row[0].strip

        next if channel_id.empty?
        subscriptions << channel_id
      end

      return subscriptions
    end

    def parse_playlist_export_csv(user : User, raw_input : String)
      # Split the input into head and body content
      raw_head, raw_body = raw_input.strip('\n').split("\n\n", limit: 2, remove_empty: true)

      # Create the playlist from the head content
      csv_head = CSV.new(raw_head.strip('\n'), headers: true)
      csv_head.next
      title = csv_head[4]
      description = csv_head[5]
      visibility = csv_head[6]

      if visibility.compare("Public", case_insensitive: true) == 0
        privacy = PlaylistPrivacy::Public
      else
        privacy = PlaylistPrivacy::Private
      end

      playlist = create_playlist(title, privacy, user)
      Invidious::Database::Playlists.update_description(playlist.id, description)

      # Add each video to the playlist from the body content
      csv_body = CSV.new(raw_body.strip('\n'), headers: true)
      csv_body.each do |row|
        video_id = row[0]
        if playlist
          next if !video_id
          next if video_id == "Video Id"

          begin
            video = get_video(video_id)
          rescue ex
            next
          end

          playlist_video = PlaylistVideo.new({
            title:          video.title,
            id:             video.id,
            author:         video.author,
            ucid:           video.ucid,
            length_seconds: video.length_seconds,
            published:      video.published,
            plid:           playlist.id,
            live_now:       video.live_now,
            index:          Random::Secure.rand(0_i64..Int64::MAX),
          })

          Invidious::Database::PlaylistVideos.insert(playlist_video)
          Invidious::Database::Playlists.update_video_added(playlist.id, playlist_video.index)
        end
      end

      return playlist
    end

    # -------------------
    #  Invidious
    # -------------------

    # Import from another invidious account
    def from_invidious(user : User, body : String)
      data = JSON.parse(body)

      if data["subscriptions"]?
        user.subscriptions += data["subscriptions"].as_a.map(&.as_s)
        user.subscriptions.uniq!
        user.subscriptions = get_batch_channels(user.subscriptions)

        Invidious::Database::Users.update_subscriptions(user)
      end

      if data["watch_history"]?
        user.watched += data["watch_history"].as_a.map(&.as_s)
        user.watched.reverse!.uniq!.reverse!
        Invidious::Database::Users.update_watch_history(user)
      end

      if data["preferences"]?
        user.preferences = Preferences.from_json(data["preferences"].to_json)
        Invidious::Database::Users.update_preferences(user)
      end

      if playlists = data["playlists"]?.try &.as_a?
        playlists.each do |item|
          title = item["title"]?.try &.as_s?.try &.delete("<>")
          description = item["description"]?.try &.as_s?.try &.delete("\r")
          privacy = item["privacy"]?.try &.as_s?.try { |privacy| PlaylistPrivacy.parse? privacy }

          next if !title
          next if !description
          next if !privacy

          playlist = create_playlist(title, privacy, user)
          Invidious::Database::Playlists.update_description(playlist.id, description)

          videos = item["videos"]?.try &.as_a?.try &.each_with_index do |video_id, idx|
            if idx > CONFIG.playlist_length_limit
              raise InfoException.new("Playlist cannot have more than #{CONFIG.playlist_length_limit} videos")
            end

            video_id = video_id.try &.as_s?
            next if !video_id

            begin
              video = get_video(video_id, false)
            rescue ex
              next
            end

            playlist_video = PlaylistVideo.new({
              title:          video.title,
              id:             video.id,
              author:         video.author,
              ucid:           video.ucid,
              length_seconds: video.length_seconds,
              published:      video.published,
              plid:           playlist.id,
              live_now:       video.live_now,
              index:          Random::Secure.rand(0_i64..Int64::MAX),
            })

            Invidious::Database::PlaylistVideos.insert(playlist_video)
            Invidious::Database::Playlists.update_video_added(playlist.id, playlist_video.index)
          end
        end
      end
    end

    # -------------------
    #  Youtube
    # -------------------

    private def is_opml?(mimetype : String, extension : String)
      opml_mimetypes = [
        "application/xml",
        "text/xml",
        "text/x-opml",
        "text/x-opml+xml",
      ]

      opml_extensions = ["xml", "opml"]

      return opml_mimetypes.any?(&.== mimetype) || opml_extensions.any?(&.== extension)
    end

    # Import subscribed channels from Youtube
    # Returns success status
    def from_youtube(user : User, body : String, filename : String, type : String) : Bool
      extension = filename.split(".").last

      if is_opml?(type, extension)
        subscriptions = XML.parse(body)
        user.subscriptions += subscriptions.xpath_nodes(%q(//outline[@type="rss"])).map do |channel|
          channel["xmlUrl"].match(/UC[a-zA-Z0-9_-]{22}/).not_nil![0]
        end
      elsif extension == "json" || type == "application/json"
        subscriptions = JSON.parse(body)
        user.subscriptions += subscriptions.as_a.compact_map do |entry|
          entry["snippet"]["resourceId"]["channelId"].as_s
        end
      elsif extension == "csv" || type == "text/csv"
        subscriptions = parse_subscription_export_csv(body)
        user.subscriptions += subscriptions
      else
        return false
      end

      user.subscriptions.uniq!
      user.subscriptions = get_batch_channels(user.subscriptions)

      Invidious::Database::Users.update_subscriptions(user)
      return true
    end

    def from_youtube_pl(user : User, body : String, filename : String, type : String) : Bool
      extension = filename.split(".").last

      if extension == "csv" || type == "text/csv"
        playlist = parse_playlist_export_csv(user, body)
        if playlist
          return true
        else
          return false
        end
      else
        return false
      end
    end

    # -------------------
    #  Freetube
    # -------------------

    def from_freetube(user : User, body : String)
      # Legacy import?
      matches = body.scan(/"channelId":"(?<channel_id>[a-zA-Z0-9_-]{24})"/)
      subs = matches.map(&.["channel_id"])

      if subs.empty?
        data = JSON.parse(body)["subscriptions"]
        subs = data.as_a.map(&.["id"].as_s)
      end

      user.subscriptions += subs
      user.subscriptions.uniq!
      user.subscriptions = get_batch_channels(user.subscriptions)

      Invidious::Database::Users.update_subscriptions(user)
    end

    # -------------------
    #  Newpipe
    # -------------------

    def from_newpipe_subs(user : User, body : String)
      data = JSON.parse(body)

      user.subscriptions += data["subscriptions"].as_a.compact_map do |channel|
        if match = channel["url"].as_s.match(/\/channel\/(?<channel>UC[a-zA-Z0-9_-]{22})/)
          next match["channel"]
        elsif match = channel["url"].as_s.match(/\/user\/(?<user>.+)/)
          # Resolve URL using the API
          resolved_url = YoutubeAPI.resolve_url("https://www.youtube.com/user/#{match["user"]}")
          ucid = resolved_url.dig?("endpoint", "browseEndpoint", "browseId")
          next ucid.as_s if ucid
        end

        nil
      end

      user.subscriptions.uniq!
      user.subscriptions = get_batch_channels(user.subscriptions)

      Invidious::Database::Users.update_subscriptions(user)
    end

    def from_newpipe(user : User, body : String) : Bool
      io = IO::Memory.new(body)

      Compress::Zip::File.open(io) do |file|
        file.entries.each do |entry|
          entry.open do |file_io|
            # Ensure max size of 4MB
            io_sized = IO::Sized.new(file_io, 0x400000)

            next if entry.filename != "newpipe.db"

            tempfile = File.tempfile(".db")

            begin
              File.write(tempfile.path, io_sized.gets_to_end)
            rescue
              return false
            end

            db = DB.open("sqlite3://" + tempfile.path)

            user.watched += db.query_all("SELECT url FROM streams", as: String)
              .map(&.lchop("https://www.youtube.com/watch?v="))

            user.watched.uniq!
            Invidious::Database::Users.update_watch_history(user)

            user.subscriptions += db.query_all("SELECT url FROM subscriptions", as: String)
              .map(&.lchop("https://www.youtube.com/channel/"))

            user.subscriptions.uniq!
            user.subscriptions = get_batch_channels(user.subscriptions)

            Invidious::Database::Users.update_subscriptions(user)

            db.close
            tempfile.delete
          end
        end
      end

      # Success!
      return true
    end
  end # module
end
