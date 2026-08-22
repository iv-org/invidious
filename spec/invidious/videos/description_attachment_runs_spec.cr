require "../../parsers_helper.cr"

Spectator.describe "parse_description" do
  # Real InnerTube data captured from YouTube comments (2026-08).
  # Standard emojis are attached as images hosted on www.youtube.com, while
  # custom channel emojis are hosted on yt3.ggpht.com.

  it "keeps standard emoji characters when their image is not proxyable" do
    desc = JSON.parse(%q({"content":"Not going to lie. Your intro got me to sub!  Watching you, everyone deserves to grow❤️","attachmentRuns":[{"startIndex":84,"length":1,"element":{"type":{"imageType":{"image":{"sources":[{"url":"https://www.youtube.com/s/gaming/emoji/7ff574f2/emoji_u2764.png","width":16,"height":16}]},"playbackState":"IMAGE_PLAYBACK_STATE_STOPPED"}},"properties":{"layoutProperties":{"height":{"value":16,"unit":"DIMENSION_UNIT_POINT"},"width":{"value":16,"unit":"DIMENSION_UNIT_POINT"},"margin":{"left":{"value":2,"unit":"DIMENSION_UNIT_POINT"},"right":{"value":2,"unit":"DIMENSION_UNIT_POINT"}}},"accessibilityProperties":{"label":"❤"}}},"alignment":"ALIGNMENT_VERTICAL_CENTER"}]}))

    html = parse_description(desc, "Gy3bmuzmWMM")

    expect(html).to eq(%(Not going to lie. Your intro got me to sub!  Watching you, everyone deserves to grow\u{2764}\u{fe0f}))
    expect(html.not_nil!.includes?("img")).to be_false
  end

  it "handles SMP emojis (2 UTF-16 units) right after multibyte-free text" do
    desc = JSON.parse(%q({"content":"Feyrer is on 🔥! Thank you again, Master Jedi.","attachmentRuns":[{"startIndex":13,"length":2,"element":{"type":{"imageType":{"image":{"sources":[{"url":"https://www.youtube.com/s/gaming/emoji/7ff574f2/emoji_u1f525.png","width":16,"height":16}]},"playbackState":"IMAGE_PLAYBACK_STATE_STOPPED"}},"properties":{"layoutProperties":{"height":{"value":16,"unit":"DIMENSION_UNIT_POINT"},"width":{"value":16,"unit":"DIMENSION_UNIT_POINT"},"margin":{"left":{"value":2,"unit":"DIMENSION_UNIT_POINT"},"right":{"value":2,"unit":"DIMENSION_UNIT_POINT"}}},"accessibilityProperties":{"label":"🔥"}}},"alignment":"ALIGNMENT_VERTICAL_CENTER"}]}))

    html = parse_description(desc, "Gy3bmuzmWMM")

    expect(html).to eq("Feyrer is on \u{1F525}! Thank you again, Master Jedi.")
  end

  it "renders proxied channel emojis as images" do
    # Fixture derived from a real capture: only the image URL was changed to
    # a yt3.ggpht.com one (custom channel emoji) and its label set accordingly.
    desc = JSON.parse(%q({"content":"Great video :_ToonThumbsUp: love it","attachmentRuns":[{"startIndex":12,"length":15,"element":{"type":{"imageType":{"image":{"sources":[{"url":"https://yt3.ggpht.com/UCxyz/aKgIYbrtFqmL8gT4576oCA=w24-h24-c-k-nd","width":24,"height":24}]}}},"properties":{"accessibilityProperties":{"label":"ToonThumbsUp"}}}}]}))

    html = parse_description(desc, "Gy3bmuzmWMM")

    expect(html).to eq(%(Great video <img alt="ToonThumbsUp" title="ToonThumbsUp" src="/ggpht/UCxyz/aKgIYbrtFqmL8gT4576oCA=w24-h24-c-k-nd" width="24" height="24" class="channel-emoji" /> love it))
  end

  it "renders links and channel emojis in order when both are present" do
    # Minimal synthetic fixture: a command run without onTap stays as plain
    # text, followed by a proxyable emoji attachment.
    desc = JSON.parse(%q({"content":"see docs now :ToonFire:","attachmentRuns":[{"startIndex":13,"length":10,"element":{"type":{"imageType":{"image":{"sources":[{"url":"https://yt3.ggpht.com/x/fire.png"}]}}},"properties":{"accessibilityProperties":{"label":"ToonFire"}}}}],"commandRuns":[{"startIndex":4,"length":4}]}))

    html = parse_description(desc, "Gy3bmuzmWMM")

    expect(html).to eq(%(see docs now <img alt="ToonFire" title="ToonFire" src="/ggpht/x/fire.png" width="16" height="16" class="channel-emoji" />))
  end

  it "escapes HTML entities in the fast path" do
    desc = JSON.parse(%q({"content":"a<b & c"}))

    expect(parse_description(desc, "x")).to eq("a&lt;b &amp; c")
  end
end
