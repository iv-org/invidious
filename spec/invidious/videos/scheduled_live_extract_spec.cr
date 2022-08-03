require "../../parsers_helper.cr"

Spectator.describe Invidious::Hashtag do
  it "parses scheduled livestreams data (test 1)" do
    # Enable mock
    _player = load_mock("video/scheduled_live_nintendo.player")
    _next = load_mock("video/scheduled_live_nintendo.next")

    raw_data = _player.merge!(_next)
    info = parse_video_info("QMGibBzTu0g", raw_data)

    # Some basic verifications
    expect(typeof(info)).to eq(Hash(String, JSON::Any))

    expect(info["shortDescription"].as_s).to eq(
      "Tune in on 6/22 at 7 a.m. PT for a livestreamed Xenoblade Chronicles 3 Direct presentation featuring roughly 20 minutes of information about the upcoming RPG adventure for Nintendo Switch."
    )
    expect(info["descriptionHtml"].as_s).to eq(
      "Tune in on 6/22 at 7 a.m. PT for a livestreamed Xenoblade Chronicles 3 Direct presentation featuring roughly 20 minutes of information about the upcoming RPG adventure for Nintendo Switch."
    )

    expect(info["likes"].as_i).to eq(2_283)

    expect(info["genre"].as_s).to eq("Gaming")
    expect(info["genreUrl"].raw).to be_nil
    expect(info["genreUcid"].as_s).to be_empty
    expect(info["license"].as_s).to be_empty

    expect(info["authorThumbnail"].as_s).to eq(
      "https://yt3.ggpht.com/ytc/AKedOLTt4vtjREUUNdHlyu9c4gtJjG90M9jQheRlLKy44A=s48-c-k-c0x00ffffff-no-rj"
    )

    expect(info["authorVerified"].as_bool).to be_true
    expect(info["subCountText"].as_s).to eq("8.5M")

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
  end

  it "parses scheduled livestreams data (test 2)" do
    # Enable mock
    _player = load_mock("video/scheduled_live_PBD-Podcast.player")
    _next = load_mock("video/scheduled_live_PBD-Podcast.next")

    raw_data = _player.merge!(_next)
    info = parse_video_info("RG0cjYbXxME", raw_data)

    # Some basic verifications
    expect(typeof(info)).to eq(Hash(String, JSON::Any))

    expect(info["shortDescription"].as_s).to start_with(
      <<-TXT
      PBD Podcast Episode 171. In this episode, Patrick Bet-David is joined by Dr. Patrick Moore and Adam Sosnick.

      Join the channel to get exclusive access to perks: https://bit.ly/3Q9rSQL
      TXT
    )
    expect(info["descriptionHtml"].as_s).to start_with(
      <<-TXT
      PBD Podcast Episode 171. In this episode, Patrick Bet-David is joined by Dr. Patrick Moore and Adam Sosnick.

      Join the channel to get exclusive access to perks: <a href="https://bit.ly/3Q9rSQL">bit.ly/3Q9rSQL</a>
      TXT
    )

    expect(info["likes"].as_i).to eq(22)

    expect(info["genre"].as_s).to eq("Entertainment")
    expect(info["genreUrl"].raw).to be_nil
    expect(info["genreUcid"].as_s).to be_empty
    expect(info["license"].as_s).to be_empty

    expect(info["authorThumbnail"].as_s).to eq(
      "https://yt3.ggpht.com/61ArDiQshJrvSXcGLhpFfIO3hlMabe2fksitcf6oGob0Mdr5gztdkXxRljICUodL4iuTSrtxW4A=s48-c-k-c0x00ffffff-no-rj"
    )

    expect(info["authorVerified"].as_bool).to be_false
    expect(info["subCountText"].as_s).to eq("227K")

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
  end
end
