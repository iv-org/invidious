require "../../parsers_helper.cr"

Spectator.describe "parse_video_info" do
  it "parses scheduled livestreams data (test 1)" do
    # Enable mock
    _player = load_mock("video/scheduled_live_nintendo.player")
    _next = load_mock("video/scheduled_live_nintendo.next")

    raw_data = _player.merge!(_next)
    info = parse_video_info("QMGibBzTu0g", raw_data)

    # Some basic verifications
    expect(typeof(info)).to eq(Hash(String, JSON::Any))

    expect(info["videoType"].as_s).to eq("Scheduled")

    # Basic video infos

    expect(info["title"].as_s).to eq("Xenoblade Chronicles 3 Nintendo Direct")
    expect(info["views"].as_i).to eq(160)
    expect(info["likes"].as_i).to eq(2_283)
    expect(info["lengthSeconds"].as_i).to eq(0_i64)
    expect(info["published"].as_s).to eq("2022-06-22T14:00:00Z") # Unix 1655906400

    # Extra video infos

    expect(info["allowedRegions"].as_a).to_not be_empty
    expect(info["allowedRegions"].as_a.size).to eq(249)

    expect(info["allowedRegions"].as_a).to contain(
      "AD", "BA", "BB", "BW", "BY", "EG", "GG", "HN", "NP", "NR", "TR",
      "TT", "TV", "TW", "TZ", "VA", "VC", "VE", "VG", "VI", "VN", "VU",
      "WF", "WS", "YE", "YT", "ZA", "ZM", "ZW"
    )

    expect(info["keywords"].as_a).to_not be_empty
    expect(info["keywords"].as_a.size).to eq(11)

    expect(info["keywords"].as_a).to contain_exactly(
      "nintendo",
      "game",
      "gameplay",
      "fun",
      "video game",
      "action",
      "adventure",
      "rpg",
      "play",
      "switch",
      "nintendo switch"
    ).in_any_order

    expect(info["allowRatings"].as_bool).to be_true
    expect(info["isFamilyFriendly"].as_bool).to be_true
    expect(info["isListed"].as_bool).to be_true
    expect(info["isUpcoming"].as_bool).to be_true

    # Related videos

    expect(info["relatedVideos"].as_a.size).to eq(20)

    # related video #1
    expect(info["relatedVideos"][3]["id"].as_s).to eq("a-SN3lLIUEo")
    expect(info["relatedVideos"][3]["author"].as_s).to eq("Nintendo")
    expect(info["relatedVideos"][3]["ucid"].as_s).to eq("UCGIY_O-8vW4rfX98KlMkvRg")
    expect(info["relatedVideos"][3]["view_count"].as_s).to eq("147796")
    expect(info["relatedVideos"][3]["short_view_count"].as_s).to eq("147K")
    expect(info["relatedVideos"][3]["author_verified"].as_s).to eq("true")

    # Related video #2
    expect(info["relatedVideos"][16]["id"].as_s).to eq("l_uC1jFK0lo")
    expect(info["relatedVideos"][16]["author"].as_s).to eq("Nintendo")
    expect(info["relatedVideos"][16]["ucid"].as_s).to eq("UCGIY_O-8vW4rfX98KlMkvRg")
    expect(info["relatedVideos"][16]["view_count"].as_s).to eq("53510")
    expect(info["relatedVideos"][16]["short_view_count"].as_s).to eq("53K")
    expect(info["relatedVideos"][16]["author_verified"].as_s).to eq("true")

    # Description

    description = "Tune in on 6/22 at 7 a.m. PT for a livestreamed Xenoblade Chronicles 3 Direct presentation featuring roughly 20 minutes of information about the upcoming RPG adventure for Nintendo Switch."

    expect(info["description"].as_s).to eq(description)
    expect(info["shortDescription"].as_s).to eq(description)
    expect(info["descriptionHtml"].as_s).to eq(description)

    # Video metadata

    expect(info["genre"].as_s).to eq("Gaming")
    expect(info["genreUcid"].as_s).to be_empty
    expect(info["license"].as_s).to be_empty

    # Author infos

    expect(info["author"].as_s).to eq("Nintendo")
    expect(info["ucid"].as_s).to eq("UCGIY_O-8vW4rfX98KlMkvRg")

    expect(info["authorThumbnail"].as_s).to eq(
      "https://yt3.ggpht.com/ytc/AKedOLTt4vtjREUUNdHlyu9c4gtJjG90M9jQheRlLKy44A=s48-c-k-c0x00ffffff-no-rj"
    )

    expect(info["authorVerified"].as_bool).to be_true
    expect(info["subCountText"].as_s).to eq("8.5M")
  end

  it "parses scheduled livestreams data (test 2)" do
    # Enable mock
    _player = load_mock("video/scheduled_live_PBD-Podcast.player")
    _next = load_mock("video/scheduled_live_PBD-Podcast.next")

    raw_data = _player.merge!(_next)
    info = parse_video_info("RG0cjYbXxME", raw_data)

    # Some basic verifications
    expect(typeof(info)).to eq(Hash(String, JSON::Any))

    expect(info["videoType"].as_s).to eq("Scheduled")

    # Basic video infos

    expect(info["title"].as_s).to eq("The Truth About Greenpeace w/ Dr. Patrick Moore | PBD Podcast | Ep. 171")
    expect(info["views"].as_i).to eq(24)
    expect(info["likes"].as_i).to eq(22)
    expect(info["lengthSeconds"].as_i).to eq(0_i64)
    expect(info["published"].as_s).to eq("2022-07-14T13:00:00Z") # Unix 1657803600

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

    # related video #1
    expect(info["relatedVideos"][2]["id"]).to eq("La9oLLoI5Rc")
    expect(info["relatedVideos"][2]["author"]).to eq("Tom Bilyeu")
    expect(info["relatedVideos"][2]["ucid"]).to eq("UCnYMOamNKLGVlJgRUbamveA")
    expect(info["relatedVideos"][2]["view_count"]).to eq("13329149")
    expect(info["relatedVideos"][2]["short_view_count"]).to eq("13M")
    expect(info["relatedVideos"][2]["author_verified"]).to eq("true")

    # Related video #2
    expect(info["relatedVideos"][9]["id"]).to eq("IQ_4fvpzYuA")
    expect(info["relatedVideos"][9]["author"]).to eq("Business Today")
    expect(info["relatedVideos"][9]["ucid"]).to eq("UCaPHWiExfUWaKsUtENLCv5w")
    expect(info["relatedVideos"][9]["view_count"]).to eq("26432")
    expect(info["relatedVideos"][9]["short_view_count"]).to eq("26K")
    expect(info["relatedVideos"][9]["author_verified"]).to eq("true")

    # Description

    description_start_text = <<-TXT
    PBD Podcast Episode 171. In this episode, Patrick Bet-David is joined by Dr. Patrick Moore and Adam Sosnick.

    Join the channel to get exclusive access to perks: https://bit.ly/3Q9rSQL
    TXT

    expect(info["description"].as_s).to start_with(description_start_text)
    expect(info["shortDescription"].as_s).to start_with(description_start_text)

    expect(info["descriptionHtml"].as_s).to start_with(
      <<-TXT
      PBD Podcast Episode 171. In this episode, Patrick Bet-David is joined by Dr. Patrick Moore and Adam Sosnick.

      Join the channel to get exclusive access to perks: <a href="https://bit.ly/3Q9rSQL">bit.ly/3Q9rSQL</a>
      TXT
    )

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
    expect(info["subCountText"].as_s).to eq("227K")
  end
end
