require "../../../src/invidious/frontend/video_title"
require "spectator"

Spectator.configure do |config|
  config.fail_blank
  config.randomize
end

Spectator.describe Invidious::Frontend::VideoTitle do
  it "preserves an empty title" do
    expect(described_class.to_html("")).to eq("")
  end

  it "escapes a title without hashtags" do
    expect(described_class.to_html(%q(A < B & "C" > D's))).to eq("A &lt; B &amp; &quot;C&quot; &gt; D&#39;s")
  end

  it "links a hashtag at the start of a title" do
    expect(described_class.to_html("#music live")).to eq(%q(<a href="/hashtag/music">#music</a> live))
  end

  it "links multiple hashtags including one at the end" do
    expect(described_class.to_html("Live #music and #shorts")).to eq(
      %q(Live <a href="/hashtag/music">#music</a> and <a href="/hashtag/shorts">#shorts</a>)
    )
  end

  it "keeps punctuation outside hashtag links" do
    expect(described_class.to_html("(#music), #live!")).to eq(
      %q((<a href="/hashtag/music">#music</a>), <a href="/hashtag/live">#live</a>!)
    )
  end

  it "supports numbers and underscores" do
    expect(described_class.to_html("#2026 #live_music")).to eq(
      %q(<a href="/hashtag/2026">#2026</a> <a href="/hashtag/live_music">#live_music</a>)
    )
  end

  it "preserves Unicode text around and inside hashtags" do
    expect(described_class.to_html("音楽 🎵 #日本語 — #موسيقى")).to eq(
      %q(音楽 🎵 <a href="/hashtag/%E6%97%A5%E6%9C%AC%E8%AA%9E">#日本語</a> — <a href="/hashtag/%D9%85%D9%88%D8%B3%D9%8A%D9%82%D9%89">#موسيقى</a>)
    )
  end

  it "includes combining marks without normalizing the query" do
    expect(described_class.to_html("#cafe\u0301")).to eq(
      %q(<a href="/hashtag/cafe%CC%81">#café</a>)
    )
  end

  it "preserves whitespace and stops at it" do
    expect(described_class.to_html("\t#music\n#live ")).to eq(
      "\t<a href=\"/hashtag/music\">#music</a>\n<a href=\"/hashtag/live\">#live</a> "
    )
  end

  it "does not link bare hashes, embedded hashes or URL fragments" do
    title = "# ## C# F#lang word#tag https://example.com/#section https://example.com#other"
    expect(described_class.to_html(title)).to eq(title)
  end

  it "does not link query-value URL fragments" do
    title = "https://example.com?q=#section https://example.com/?next=#music"
    expect(described_class.to_html(title)).to eq(title)
  end

  it "does not turn literal or generated HTML entities into links" do
    expect(described_class.to_html(%q(' &#39; &#x27;))).to eq("&#39; &amp;#39; &amp;#x27;")
  end

  it "escapes markup and query delimiters next to hashtags" do
    expect(described_class.to_html(%q(<script>alert('x')</script> #safe&x="bad"))).to eq(
      %q(&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt; <a href="/hashtag/safe">#safe</a>&amp;x=&quot;bad&quot;)
    )
  end
end
