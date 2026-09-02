require "../../spec_helper"
require "../../../src/invidious/frontend/watch_page"

Spectator.describe Invidious::Frontend::WatchPage do
  describe ".linkify_title_hashtags" do
    it "links hashtags while preserving surrounding punctuation" do
      result = Invidious::Frontend::WatchPage.linkify_title_hashtags(
        "Watch (#music), then #news!"
      )

      expect(result).to eq(
        %(Watch (<a href="/hashtag/music">#music</a>), then <a href="/hashtag/news">#news</a>!)
      )
    end

    it "does not link hashes inside words or without a name" do
      result = Invidious::Frontend::WatchPage.linkify_title_hashtags(
        "C# test#music #"
      )

      expect(result).to eq("C# test#music #")
    end

    it "links and encodes Unicode hashtags" do
      hashtag = "\u{97F3}\u{4E50}"

      result = Invidious::Frontend::WatchPage.linkify_title_hashtags(
        "Listen ##{hashtag}"
      )

      expect(result).to eq(
        %(Listen <a href="/hashtag/%E9%9F%B3%E4%B9%90">##{hashtag}</a>)
      )
    end

    it "escapes title markup and link text" do
      result = Invidious::Frontend::WatchPage.linkify_title_hashtags(
        %(<script>#music</script> & #news)
      )

      expect(result).to eq(
        %(&lt;script&gt;<a href="/hashtag/music">#music</a>&lt;/script&gt; &amp; <a href="/hashtag/news">#news</a>)
      )
    end

    it "does not turn character-reference-like text into hashtag links" do
      result = Invidious::Frontend::WatchPage.linkify_title_hashtags(
        "Literal &#65; and &#x41; plus #music"
      )

      expect(result).to eq(
        %(Literal &amp;#65; and &amp;#x41; plus <a href="/hashtag/music">#music</a>)
      )
    end
  end
end
