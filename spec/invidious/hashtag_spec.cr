require "../parsers_helper.cr"

Spectator.describe Invidious::Hashtag do
  it "parses richItemRenderer containers (test 1)" do
    # Enable mock
    test_content = load_mock("hashtag/martingarrix_page1").as_h
    videos, _ = extract_items(test_content)

    expect(typeof(videos)).to eq(Array(SearchItem))
    expect(videos.size).to eq(60)

    #
    # Random video check 1
    #
    expect(typeof(videos[11])).to eq(SearchItem)

    video_11 = videos[11].as(SearchVideo)

    expect(video_11.id).to eq("06eSsOWcKYA")
    expect(video_11.title).to eq("Martin Garrix - Live @ Tomorrowland 2018")

    expect(video_11.ucid).to eq("UC5H_KXkPbEsGs0tFt8R35mA")
    expect(video_11.author).to eq("Martin Garrix")
    expect(video_11.author_verified).to be_true

    expect(video_11.published).to be_close(Time.utc - 3.years, 1.second)
    expect(video_11.length_seconds).to eq((56.minutes + 41.seconds).total_seconds.to_i32)
    expect(video_11.views).to eq(40_504_893)

    expect(video_11.badges.live_now?).to be_false
    expect(video_11.badges.premium?).to be_false
    expect(video_11.premiere_timestamp).to be_nil

    #
    # Random video check 2
    #
    expect(typeof(videos[35])).to eq(SearchItem)

    video_35 = videos[35].as(SearchVideo)

    expect(video_35.id).to eq("b9HpOAYjY9I")
    expect(video_35.title).to eq("Martin Garrix feat. Mike Yung - Dreamer (Official Video)")

    expect(video_35.ucid).to eq("UC5H_KXkPbEsGs0tFt8R35mA")
    expect(video_35.author).to eq("Martin Garrix")
    expect(video_35.author_verified).to be_true

    expect(video_35.published).to be_close(Time.utc - 3.years, 1.second)
    expect(video_35.length_seconds).to eq((3.minutes + 14.seconds).total_seconds.to_i32)
    expect(video_35.views).to eq(30_790_049)

    expect(video_35.badges.live_now?).to be_false
    expect(video_35.badges.premium?).to be_false
    expect(video_35.premiere_timestamp).to be_nil
  end

  it "parses richItemRenderer containers (test 2)" do
    # Enable mock
    test_content = load_mock("hashtag/martingarrix_page2").as_h
    videos, _ = extract_items(test_content)

    expect(typeof(videos)).to eq(Array(SearchItem))
    expect(videos.size).to eq(60)

    #
    # Random video check 1
    #
    expect(typeof(videos[41])).to eq(SearchItem)

    video_41 = videos[41].as(SearchVideo)

    expect(video_41.id).to eq("qhstH17zAjs")
    expect(video_41.title).to eq("Martin Garrix Radio - Episode 391")

    expect(video_41.ucid).to eq("UC5H_KXkPbEsGs0tFt8R35mA")
    expect(video_41.author).to eq("Martin Garrix")
    expect(video_41.author_verified).to be_true

    expect(video_41.published).to be_close(Time.utc - 2.months, 1.second)
    expect(video_41.length_seconds).to eq((1.hour).total_seconds.to_i32)
    expect(video_41.views).to eq(63_240)

    expect(video_41.badges.live_now?).to be_false
    expect(video_41.badges.premium?).to be_false
    expect(video_41.premiere_timestamp).to be_nil

    #
    # Random video check 2
    #
    expect(typeof(videos[48])).to eq(SearchItem)

    video_48 = videos[48].as(SearchVideo)

    expect(video_48.id).to eq("lqGvW0NIfdc")
    expect(video_48.title).to eq("Martin Garrix SENTIO Full Album Mix by Sakul")

    expect(video_48.ucid).to eq("UC3833PXeLTS6yRpwGMQpp4Q")
    expect(video_48.author).to eq("SAKUL")
    expect(video_48.author_verified).to be_false

    expect(video_48.published).to be_close(Time.utc - 3.weeks, 1.second)
    expect(video_48.length_seconds).to eq((35.minutes + 46.seconds).total_seconds.to_i32)
    expect(video_48.views).to eq(68_704)

    expect(video_48.badges.live_now?).to be_false
    expect(video_48.badges.premium?).to be_false
    expect(video_48.premiere_timestamp).to be_nil
  end
end
