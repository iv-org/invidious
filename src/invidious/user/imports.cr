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

    def parse_playlist_export_csv(user : User, raw_input : String, filename : String)
      LOGGER.trace("parse_playlist_export_csv: 01 raw_input '#{raw_input}'\n")

      raw_head = "" # playlists.csv - info-line for a given playlist in the google export, that's copied above the actual playlist-infos and separated by an empty line from
      raw_body = "" # the actual playlist content, ie. a list of videos

      # remove superfluous \n instances in front of and after any non-\n text.. so .. a trim?
      raw_input = raw_input.strip('\n')

      # Split the input into head and body content
      tmp = raw_input.split("\n\n", limit: 2, remove_empty: true)
      if tmp.size > 1
        raw_head = tmp[0]
        raw_body = tmp[1]
      else
        raw_body = tmp[0]
      end

      LOGGER.trace("parse_playlist_export_csv: 02 raw_head '#{raw_head}' -----\nraw_body '#{raw_body}'\n")

      # TODO create an import-feature (elsewhere), which works for the original google export format, ie. the playlists/ subdirectory content as a ZIP file.. or a complete youtube music export file, but this goes way beyond the scope of a playlist import.

      # defaults
      title = "title not set"          # TODO i8n
      description = "from #{filename}" # TODO i8n
      visibility = "Private"
      privacy = PlaylistPrivacy::Private

      if (raw_head != "")
        # ## XXX for documentation of current file format of playlists.csv (today it's 2024-01-07):
        # 0           1                     2                                 3                    4                       5                      6                         7                                  8                         9                         10                   11
        # Playlist ID,Add new videos to top,Playlist image 1 Create timestamp,Playlist image 1 URL,Playlist image 1 Height,Playlist image 1 Width,Playlist title (original),Playlist title (original) language,Playlist create timestamp,Playlist update timestamp,Playlist video order,Playlist visibility
        # PLc5oiabcabcabcabcabcrOvXgzabcabcm,False,,,,,display name of playlist,,2015-01-01T01:02:03+00:00,2022-10-28T02:23:15+00:00,Manual,Public' ---
        # ##/documentation

        # Create the playlist from the head content (if it seems to be valid):
        csv_head = CSV.new(raw_head.strip('\n'), headers: true)
        csv_head.next
        if csv_head[11]
          LOGGER.info("parse_playlist_export_csv: 03.1 raw_head is filled, doing dual csv playlist info scan. google takeout format after october 2023 (format seems to be one line of playlist metadata taken out of the google export's playlists.csv file, added above the actual playlist.csv content, separated by an empty line)")
          title = csv_head[6]
          description = "Playlist was imported from file '#{filename}'\n\nCreated on #{csv_head[8]}\nLast updated on #{csv_head[9]}\n" # TODO i8n
          visibility = csv_head[11]
        elsif csv_head[6]
          LOGGER.info("parse_playlist_export_csv: 03.2 raw_head is filled, doing dual csv playlist info scan. google takeout format before october 2023 (roughly).")
          title = csv_head[4]
          description = csv_head[5]
          visibility = csv_head[6]
        else # we are using the defaults defined above instead.
          LOGGER.info("parse_playlist_export_csv: 03.3 raw_head is filled, but in an unknown format. Using base defaults instead.")
        end

        if visibility.compare("Public", case_insensitive: true) == 0
          privacy = PlaylistPrivacy::Public
        else
          privacy = PlaylistPrivacy::Private
        end
      else # choose a title from the provided upload filename
        LOGGER.info("parse_playlist_export_csv: 03.2 raw_head is empty. Trying to guess fine-looking title and description from the provided upload filename.")
        if (filename != "")
          title = filename
        end
        nameendpos = filename.rindex(" videos.", filename.size) # XXX everything up to " videos.csv"
        if !nameendpos                                          # XXX everything up to file extension
          nameendpos = filename.rindex(".", filename.size)
        end
        if nameendpos
          title = filename[0, nameendpos]
        end
      end

      playlist = create_playlist(title, privacy, user)
      Invidious::Database::Playlists.update_description(playlist.id, description)

      # Add each video to the playlist from the body content
      csv_body = CSV.new(raw_body.strip('\n'), headers: true)
      csv_body.each do |row|
        video_id = row[0]
        if playlist
          next if !video_id
          next if video_id == "Video Id" # TODO i8n

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
          privacy = item["privacy"]?.try &.as_s?.try { |raw_pl_privacy_state| PlaylistPrivacy.parse? raw_pl_privacy_state }

          next if !title
          next if !description
          next if !privacy

          playlist = create_playlist(title, privacy, user)
          Invidious::Database::Playlists.update_description(playlist.id, description)

          item["videos"]?.try &.as_a?.try &.each_with_index do |video_id, idx|
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

    private def opml?(mimetype : String, extension : String)
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

      if opml?(type, extension)
        subscriptions = XML.parse(body)
        user.subscriptions += subscriptions.xpath_nodes(%q(//outline[@type="rss"])).map do |channel|
          channel["xmlUrl"].match!(/UC[a-zA-Z0-9_-]{22}/)[0]
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
        playlist = parse_playlist_export_csv(user, body, filename)
        if playlist
          return true
        else
          return false
        end
      else
        return false
      end
    end

    def from_youtube_wh(user : User, body : String, filename : String, type : String) : Bool
      extension = filename.split(".").last

      if extension == "json" || type == "application/json"
        data = JSON.parse(body)
        watched = data.as_a.compact_map do |item|
          next unless url = item["titleUrl"]?
          next unless match = url.as_s.match(/\?v=(?<video_id>[a-zA-Z0-9_-]+)$/)
          match["video_id"]
        end
        watched.reverse! # YouTube have newest first
        user.watched += watched
        user.watched.uniq!
        Invidious::Database::Users.update_watch_history(user)
        return true
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
        profiles = body.split('\n', remove_empty: true)
        profiles.each do |profile|
          if data = JSON.parse(profile)["subscriptions"]?
            subs += data.as_a.map(&.["id"].as_s)
          end
        end
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
