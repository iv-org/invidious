require "../../parsers_helper.cr"

Spectator.describe "parse_video_info" do
  it "parses a regular video" do
    # Enable mock
    _player = load_mock("video/regular_mrbeast.player")
    _next = load_mock("video/regular_mrbeast.next")

    raw_data = _player.merge!(_next)
    info = Invidious::Videos::Parser.parse_video_info("2isYuQZMbdU", raw_data)

    # Some basic verifications
    expect(typeof(info)).to eq(Hash(String, JSON::Any))

    expect(info["videoType"].as_s).to eq("Video")

    # Basic video infos

    expect(info["title"].as_s).to eq("I Gave My 100,000,000th Subscriber An Island")
    expect(info["views"].as_i).to eq(220_226_287)
    expect(info["likes"].as_i).to eq(6_870_691)

    # For some reason the video length from VideoDetails and the
    # one from microformat differs by 1s...
    expect(info["lengthSeconds"].as_i).to be_between(930_i64, 931_i64)

    expect(info["published"].as_s).to eq("2022-08-04T00:00:00Z")

    # Extra video infos

    expect(info["allowedRegions"].as_a).to_not be_empty
    expect(info["allowedRegions"].as_a.size).to eq(249)

    expect(info["allowedRegions"].as_a).to contain(
      "AD", "BA", "BB", "BW", "BY", "EG", "GG", "HN", "NP", "NR", "TR",
      "TT", "TV", "TW", "TZ", "VA", "VC", "VE", "VG", "VI", "VN", "VU",
      "WF", "WS", "YE", "YT", "ZA", "ZM", "ZW"
    )

    expect(info["keywords"].as_a).to be_empty

    expect(info["allowRatings"].as_bool).to be_true
    expect(info["isFamilyFriendly"].as_bool).to be_true
    expect(info["isListed"].as_bool).to be_true
    expect(info["isUpcoming"].as_bool).to be_false

    # Related videos

    expect(info["relatedVideos"].as_a.size).to eq(20)

    expect(info["relatedVideos"][0]["id"]).to eq("krsBRQbOPQ4")
    expect(info["relatedVideos"][0]["title"]).to eq("$1 vs $250,000,000 Private Island!")
    expect(info["relatedVideos"][0]["author"]).to eq("MrBeast")
    expect(info["relatedVideos"][0]["ucid"]).to eq("UCX6OQ3DkcsbYNE6H8uQQuVA")
    expect(info["relatedVideos"][0]["short_view_count"]).to eq("230M")
    expect(info["relatedVideos"][0]["author_verified"]).to eq("true")

    # Description

    description = "🚀Launch a store on Shopify, I’ll buy from 100 random stores that do ▸ "

    expect(info["description"].as_s).to start_with(description)
    expect(info["shortDescription"].as_s).to start_with(description)
    expect(info["descriptionHtml"].as_s).to start_with(description)

    # Video metadata

    expect(info["genre"].as_s).to eq("Entertainment")
    expect(info["genreUcid"].as_s?).to be_nil
    expect(info["license"].as_s).to be_empty

    # Author infos

    expect(info["author"].as_s).to eq("MrBeast")
    expect(info["ucid"].as_s).to eq("UCX6OQ3DkcsbYNE6H8uQQuVA")

    expect(info["authorThumbnail"].as_s).to eq(
      "https://yt3.ggpht.com/fxGKYucJAVme-Yz4fsdCroCFCrANWqw0ql4GYuvx8Uq4l_euNJHgE-w9MTkLQA805vWCi-kE0g=s48-c-k-c0x00ffffff-no-rj"
    )

    expect(info["authorVerified"].as_bool).to be_true
    expect(info["subCountText"].as_s).to eq("320M")
  end

  it "parses a regular video with no descrition/comments" do
    # Enable mock
    _player = load_mock("video/regular_no-description.player")
    _next = load_mock("video/regular_no-description.next")

    raw_data = _player.merge!(_next)
    info = Invidious::Videos::Parser.parse_video_info("iuevw6218F0", raw_data)

    # Some basic verifications
    expect(typeof(info)).to eq(Hash(String, JSON::Any))

    expect(info["videoType"].as_s).to eq("Video")

    # Basic video infos

    expect(info["title"].as_s).to eq("Chris Rea - Auberge")
    expect(info["views"].as_i).to eq(14_324_584)
    expect(info["likes"].as_i).to eq(35_870)
    expect(info["lengthSeconds"].as_i).to eq(283_i64)
    expect(info["published"].as_s).to eq("2012-05-21T00:00:00Z")

    # Extra video infos

    expect(info["allowedRegions"].as_a).to_not be_empty
    expect(info["allowedRegions"].as_a.size).to eq(249)

    expect(info["allowedRegions"].as_a).to contain(
      "AD", "BA", "BB", "BW", "BY", "EG", "GG", "HN", "NP", "NR", "TR",
      "TT", "TV", "TW", "TZ", "VA", "VC", "VE", "VG", "VI", "VN", "VU",
      "WF", "WS", "YE", "YT", "ZA", "ZM", "ZW"
    )

    expect(info["keywords"].as_a).to_not be_empty
    expect(info["keywords"].as_a.size).to eq(4)

    expect(info["keywords"].as_a).to contain_exactly(
      "Chris",
      "Rea",
      "Auberge",
      "1991"
    ).in_any_order

    expect(info["allowRatings"].as_bool).to be_true
    expect(info["isFamilyFriendly"].as_bool).to be_true
    expect(info["isListed"].as_bool).to be_true
    expect(info["isUpcoming"].as_bool).to be_false

    # Related videos

    expect(info["relatedVideos"].as_a.size).to eq(20)

    expect(info["relatedVideos"][0]["id"]).to eq("gUUdQfnshJ4")
    expect(info["relatedVideos"][0]["title"]).to eq("Chris Rea - The Road To Hell 1989 Full Version")
    expect(info["relatedVideos"][0]["author"]).to eq("NEA ZIXNH")
    expect(info["relatedVideos"][0]["ucid"]).to eq("UCYMEOGcvav3gCgImK2J07CQ")
    expect(info["relatedVideos"][0]["short_view_count"]).to eq("53M")
    expect(info["relatedVideos"][0]["author_verified"]).to eq("false")

    # Description

    expect(info["description"].as_s).to eq(" ")
    expect(info["shortDescription"].as_s).to be_empty
    expect(info["descriptionHtml"].as_s).to eq("")

    # Video metadata

    expect(info["genre"].as_s).to eq("Music")
    expect(info["genreUcid"].as_s?).to be_nil
    expect(info["license"].as_s).to be_empty

    # Author infos

    expect(info["author"].as_s).to eq("ChrisReaVideos")
    expect(info["ucid"].as_s).to eq("UC_5q6nWPbD30-y6oiWF_oNA")

    expect(info["authorThumbnail"].as_s).to eq(
      "https://yt3.ggpht.com/ytc/AIdro_n71nsegpKfjeRKwn1JJmK5IVMh_7j5m_h3_1KnUUg=s48-c-k-c0x00ffffff-no-rj"
    )
    expect(info["authorVerified"].as_bool).to be_false
    expect(info["subCountText"].as_s).to eq("3.11K")
  end

  it "parses a video without videoDetails (fallback to /next data)" do
    # Build the input from an existing fixture, without videoDetails, as the
    # player response is when only the /next endpoint data is available.
    _player = load_mock("video/regular_no-description.player")
    _player.delete("videoDetails")
    _next = load_mock("video/regular_no-description.next")

    raw_data = _player.merge!(_next)
    info = Invidious::Videos::Parser.parse_video_info("no-videodetails-id", raw_data)

    expect(typeof(info)).to eq(Hash(String, JSON::Any))

    # Title falls back to videoPrimaryInfoRenderer
    expect(info["title"].as_s).to eq("Chris Rea - Auberge")

    # Views from videoPrimaryInfoRenderer
    expect(info["views"].as_i).to eq(14_324_584)

    # Likes still work (from videoPrimaryInfoRenderer buttons)
    expect(info["likes"].as_i).to eq(35_870)

    # Length from microformat
    expect(info["lengthSeconds"].as_i).to eq(283_i64)

    # Published from microformat, or dateText fallback
    expect(info["published"].as_s).to eq("2012-05-21T00:00:00Z")

    # Author from videoOwnerRenderer
    expect(info["author"].as_s).to eq("ChrisReaVideos")
    expect(info["ucid"].as_s).to eq("UC_5q6nWPbD30-y6oiWF_oNA")

    # Family friendly still comes from the microformat
    expect(info["isFamilyFriendly"].as_bool).to be_true

    # isListed is inferred from the (absent) "Unlisted" badge
    expect(info["isListed"].as_bool).to be_true

    # Description
    expect(info["descriptionHtml"].as_s).to eq("")

    # Related videos still work from /next
    expect(info["relatedVideos"].as_a.size).to eq(20)
  end

  it "doesn't assume a video is family friendly without the microformat" do
    _player = load_mock("video/regular_no-description.player")
    _player.delete("videoDetails")
    _player.delete("microformat")
    _next = load_mock("video/regular_no-description.next")

    raw_data = _player.merge!(_next)
    info = Invidious::Videos::Parser.parse_video_info("iuevw6218F0", raw_data)

    expect(info["title"].as_s).to eq("Chris Rea - Auberge")
    expect(info["isFamilyFriendly"].as_bool).to be_false
  end
end

Spectator.describe "has_unlisted_badge?" do
  it "returns false for malformed badges" do
    expect(has_unlisted_badge?(JSON::Any.new("not an array"))).to be_false
    expect(has_unlisted_badge?(nil)).to be_false
  end

  it "detects the unlisted badge" do
    badges = JSON.parse(%([{"metadataBadgeRenderer": {"icon": {"iconType": "PRIVACY_UNLISTED"}}}]))
    expect(has_unlisted_badge?(badges)).to be_true
  end
end

Spectator.describe "Video error accessors" do
  it "returns nil for a subreason stored as JSON null" do
    # Some error paths store `subreason` as a JSON `null`; the accessor must
    # not raise a TypeCastError on it.
    info = {
      "reason"    => JSON::Any.new("Video unavailable"),
      "subreason" => JSON::Any.new(nil),
    } of String => JSON::Any

    video = Video.new({id: "dQw4w9WgXcQ", info: info, updated: Time.utc})

    expect(video.reason).to eq("Video unavailable")
    expect(video.subreason).to be_nil
  end

  it "renders the minimal error record without raising" do
    # Same shape as the record built by `Parser.error_video_info`
    info = {
      "version"   => JSON::Any.new(Video::SCHEMA_VERSION.to_i64),
      "reason"    => JSON::Any.new("Sign in to confirm your age"),
      "subreason" => JSON::Any.new("This video may be inappropriate for some users."),
    } of String => JSON::Any

    video = Video.new({id: "dQw4w9WgXcQ", info: info, updated: Time.utc})

    expect(video.comments?).to be_false
    expect(video.genre_url).to be_nil
    expect(video.music).to be_empty
    expect(video.post_live_dvr).to be_false
    expect(video.error_only?).to be_true
    expect(video.unplayable_reason).to eq("Sign in to confirm your age")
    expect(video.no_backend_streams?).to be_false
  end
end
