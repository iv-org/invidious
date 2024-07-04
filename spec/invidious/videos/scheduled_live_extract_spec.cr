require "../../parsers_helper.cr"

Spectator.describe "parse_video_info" do
  it "parses scheduled livestreams data" do
    # Enable mock
    _player = load_mock("video/scheduled_live_PBD-Podcast.player")
    _next = load_mock("video/scheduled_live_PBD-Podcast.next")

    raw_data = _player.merge!(_next)
    info = parse_video_info("N-yVic7BbY0", raw_data)

    # Some basic verifications
    expect(typeof(info)).to eq(Hash(String, JSON::Any))

    expect(info["videoType"].as_s).to eq("Scheduled")

    # Basic video infos

    expect(info["title"].as_s).to eq("Home Team | PBD Podcast | Ep. 241")
    expect(info["views"].as_i).to eq(6)
    expect(info["likes"].as_i).to eq(7)
    expect(info["lengthSeconds"].as_i).to eq(0_i64)
    expect(info["published"].as_s).to eq("2023-02-28T14:00:00Z") # Unix 1677592800

    # Extra video infos

    expect(info["allowedRegions"].as_a).to_not be_empty
    expect(info["allowedRegions"].as_a.size).to eq(249)

    expect(info["allowedRegions"].as_a).to contain(
      "AD", "AR", "BA", "BT", "CZ", "FO", "GL", "IO", "KE", "KH", "LS",
      "LT", "MP", "NO", "PR", "RO", "SE", "SK", "SS", "SX", "SZ", "ZW"
    )

    expect(info["keywords"].as_a).to_not be_empty
    expect(info["keywords"].as_a.size).to eq(25)

    expect(info["keywords"].as_a).to contain_exactly(
      "Patrick Bet-David",
      "Valeutainment",
      "The BetDavid Podcast",
      "The BetDavid Show",
      "Betdavid",
      "PBD",
      "BetDavid show",
      "Betdavid podcast",
      "podcast betdavid",
      "podcast patrick",
      "patrick bet david podcast",
      "Valuetainment podcast",
      "Entrepreneurs",
      "Entrepreneurship",
      "Entrepreneur Motivation",
      "Entrepreneur Advice",
      "Startup Entrepreneurs",
      "valuetainment",
      "patrick bet david",
      "PBD podcast",
      "Betdavid show",
      "Betdavid Podcast",
      "Podcast Betdavid",
      "Show Betdavid",
      "PBDPodcast"
    ).in_any_order

    expect(info["allowRatings"].as_bool).to be_true
    expect(info["isFamilyFriendly"].as_bool).to be_true
    expect(info["isListed"].as_bool).to be_true
    expect(info["isUpcoming"].as_bool).to be_true

    # Related videos

    expect(info["relatedVideos"].as_a.size).to eq(20)

    expect(info["relatedVideos"][0]["id"]).to eq("j7jPzzjbVuk")
    expect(info["relatedVideos"][0]["author"]).to eq("Democracy Now!")
    expect(info["relatedVideos"][0]["ucid"]).to eq("UCzuqE7-t13O4NIDYJfakrhw")
    expect(info["relatedVideos"][0]["view_count"]).to eq("7576")
    expect(info["relatedVideos"][0]["short_view_count"]).to eq("7.5K")
    expect(info["relatedVideos"][0]["author_verified"]).to eq("true")

    # Description

    description_start_text = "PBD Podcast Episode 241. The home team is ready and at it again with the latest news, interesting topics and trending conversations on topics that matter. Try our sponsor Aura for 14 days free - https://aura.com/pbd"

    expect(info["description"].as_s).to start_with(description_start_text)
    expect(info["shortDescription"].as_s).to start_with(description_start_text)

    # TODO: Update mocks right before the start of PDB podcast, either on friday or saturday (time unknown)
    # expect(info["descriptionHtml"].as_s).to start_with(
    #  "PBD Podcast Episode 241. The home team is ready and at it again with the latest news, interesting topics and trending conversations on topics that matter. Try our sponsor Aura for 14 days free - <a href=\"https://aura.com/pbd\">aura.com/pbd</a>"
    # )

    # Video metadata

    expect(info["genre"].as_s).to eq("Entertainment")
    expect(info["genreUcid"].as_s).to be_empty
    expect(info["license"].as_s).to be_empty

    # Author infos

    expect(info["author"].as_s).to eq("PBD Podcast")
    expect(info["ucid"].as_s).to eq("UCGX7nGXpz-CmO_Arg-cgJ7A")

    expect(info["authorThumbnail"].as_s).to eq(
      "https://yt3.ggpht.com/61ArDiQshJrvSXcGLhpFfIO3hlMabe2fksitcf6oGob0Mdr5gztdkXxRljICUodL4iuTSrtxW4A=s48-c-k-c0x00ffffff-no-rj"
    )
    expect(info["authorVerified"].as_bool).to be_false
    expect(info["subCountText"].as_s).to eq("594K")
  end
end
