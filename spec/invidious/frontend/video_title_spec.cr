require "../../../src/invidious/frontend/video_title"
require "spectator"

Spectator.configure do |config|
  config.fail_blank
  config.randomize
end

Spectator.describe Invidious::Frontend::VideoTitle do
  it "links hashtags at the start and end of a title" do
    expect(described_class.to_html("#music live #concert")).to eq(
      %(<a href="/hashtag/music">#music</a> live <a href="/hashtag/concert">#concert</a>)
    )
  end

  it "keeps surrounding punctuation outside links" do
    expect(described_class.to_html("(#one), [#two]! {#three}. #four-five")).to eq(
      %((<a href="/hashtag/one">#one</a>), [<a href="/hashtag/two">#two</a>]! {<a href="/hashtag/three">#three</a>}. <a href="/hashtag/four">#four</a>-five)
    )
  end

  it "preserves case, numbers and underscores" do
    expect(described_class.to_html("#Open_Source2026 #123")).to eq(
      %(<a href="/hashtag/Open_Source2026">#Open_Source2026</a> <a href="/hashtag/123">#123</a>)
    )
  end

  it "supports Unicode letters and combining marks with encoded paths" do
    expect(described_class.to_html("🎵 #日本語 #cafe\u0301 #हिन्दी")).to eq(
      %(🎵 <a href="/hashtag/%E6%97%A5%E6%9C%AC%E8%AA%9E">#日本語</a> <a href="/hashtag/cafe%CC%81">#cafe\u0301</a> <a href="/hashtag/%E0%A4%B9%E0%A4%BF%E0%A4%A8%E0%A5%8D%E0%A4%A6%E0%A5%80">#हिन्दी</a>)
    )
  end

  it "preserves whitespace between consecutive hashtags" do
    expect(described_class.to_html("#one\t#two\n#three")).to eq(
      %(<a href="/hashtag/one">#one</a>\t<a href="/hashtag/two">#two</a>\n<a href="/hashtag/three">#three</a>)
    )
  end

  it "recognizes quoted hashtags and Unicode whitespace" do
    expect(described_class.to_html(%('#one' "#two"\u00a0#three))).to eq(
      %(&#39;<a href="/hashtag/one">#one</a>&#39; &quot;<a href="/hashtag/two">#two</a>&quot;\u00a0<a href="/hashtag/three">#three</a>)
    )
  end

  it "does not link word suffixes, URL fragments or bare hashes" do
    title = "C# C#Sharp word#tag https://example.com/#fragment https://example.com?q=#section # ##tag #!"
    expect(described_class.to_html(title)).to eq(title)
  end

  it "escapes markup and quotes while preserving the displayed title" do
    expect(described_class.to_html(%(<script>alert("x")</script> #safe & 'quoted'))).to eq(
      %(&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt; <a href="/hashtag/safe">#safe</a> &amp; &#39;quoted&#39;)
    )
  end

  it "does not turn escaped character references into hashtags" do
    expect(described_class.to_html(%(' " &#123; &amp; #ok))).to eq(
      %(&#39; &quot; &amp;#123; &amp;amp; <a href="/hashtag/ok">#ok</a>)
    )
  end

  it "escapes attempted attribute injection after a hashtag" do
    expect(described_class.to_html(%(#tag" onclick="alert(1)))).to eq(
      %(<a href="/hashtag/tag">#tag</a>&quot; onclick=&quot;alert(1))
    )
  end

  it "handles empty titles and titles without hashtags" do
    expect(described_class.to_html("")).to eq("")
    expect(described_class.to_html("Music & video")).to eq("Music &amp; video")
  end
end
