require "../../parsers_helper.cr"

Spectator.describe "parse_video_info" do
  it "parses a regular video" do
    # Enable mock
    _player = load_mock("video/regular_mrbeast.player")
    _next = load_mock("video/regular_mrbeast.next")

    raw_data = _player.merge!(_next)
    info = parse_video_info("2isYuQZMbdU", raw_data)

    # Some basic verifications
    expect(typeof(info)).to eq(Hash(String, JSON::Any))

    expect(info["videoType"].as_s).to eq("Video")

    # Basic video infos

    expect(info["title"].as_s).to eq("I Gave My 100,000,000th Subscriber An Island")
    expect(info["views"].as_i).to eq(115_784_415)
    expect(info["likes"].as_i).to eq(4_932_790)

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

    expect(info["relatedVideos"][0]["id"]).to eq("iogcY_4xGjo")
    expect(info["relatedVideos"][0]["title"]).to eq("$1 vs $1,000,000 Hotel Room!")
    expect(info["relatedVideos"][0]["author"]).to eq("MrBeast")
    expect(info["relatedVideos"][0]["ucid"]).to eq("UCX6OQ3DkcsbYNE6H8uQQuVA")
    expect(info["relatedVideos"][0]["view_count"]).to eq("172972109")
    expect(info["relatedVideos"][0]["short_view_count"]).to eq("172M")
    expect(info["relatedVideos"][0]["author_verified"]).to eq("true")

    # Description

    description = "🚀Launch a store on Shopify, I’ll buy from 100 random stores that do ▸ "

    expect(info["description"].as_s).to start_with(description)
    expect(info["shortDescription"].as_s).to start_with(description)
    expect(info["descriptionHtml"].as_s).to start_with(description)

    # Video metadata

    expect(info["genre"].as_s).to eq("Entertainment")
    expect(info["genreUcid"].as_s).to be_empty
    expect(info["license"].as_s).to be_empty

    # Author infos

    expect(info["author"].as_s).to eq("MrBeast")
    expect(info["ucid"].as_s).to eq("UCX6OQ3DkcsbYNE6H8uQQuVA")

    expect(info["authorThumbnail"].as_s).to eq(
      "https://yt3.ggpht.com/ytc/AL5GRJUfhQdJS6n-YJtsAf-ouS2myDavDOq_zXBfebal3Q=s48-c-k-c0x00ffffff-no-rj"
    )

    expect(info["authorVerified"].as_bool).to be_true
    expect(info["subCountText"].as_s).to eq("135M")
  end

  it "parses a regular video with no descrition/comments" do
    # Enable mock
    _player = load_mock("video/regular_no-description.player")
    _next = load_mock("video/regular_no-description.next")

    raw_data = _player.merge!(_next)
    info = parse_video_info("iuevw6218F0", raw_data)

    # Some basic verifications
    expect(typeof(info)).to eq(Hash(String, JSON::Any))

    expect(info["videoType"].as_s).to eq("Video")

    # Basic video infos

    expect(info["title"].as_s).to eq("Chris Rea - Auberge")
    expect(info["views"].as_i).to eq(10_698_554)
    expect(info["likes"].as_i).to eq(0)
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

    expect(info["relatedVideos"].as_a.size).to eq(18)

    expect(info["relatedVideos"][0]["id"]).to eq("rfyZrJUmzxU")
    expect(info["relatedVideos"][0]["title"]).to eq("cheb mami - bekatni")
    expect(info["relatedVideos"][0]["author"]).to eq("pelitovic")
    expect(info["relatedVideos"][0]["ucid"]).to eq("UCsp6vFyJeGoLxgn-AsHp1tw")
    expect(info["relatedVideos"][0]["view_count"]).to eq("13863619")
    expect(info["relatedVideos"][0]["short_view_count"]).to eq("13M")
    expect(info["relatedVideos"][0]["author_verified"]).to eq("false")

    # Description

    expect(info["description"].as_s).to eq(" ")
    expect(info["shortDescription"].as_s).to be_empty
    expect(info["descriptionHtml"].as_s).to eq("<p></p>")

    # Video metadata

    expect(info["genre"].as_s).to eq("Music")
    expect(info["genreUcid"].as_s).to be_empty
    expect(info["license"].as_s).to be_empty

    # Author infos

    expect(info["author"].as_s).to eq("ChrisReaOfficial")
    expect(info["ucid"].as_s).to eq("UC_5q6nWPbD30-y6oiWF_oNA")

    expect(info["authorThumbnail"].as_s).to be_empty
    expect(info["authorVerified"].as_bool).to be_false
    expect(info["subCountText"].as_s).to eq("-")
  end
end
