require "../../spec_helper"
require "../../../src/invidious/videos/description"

Spectator.describe "Video description parser" do
  describe "#parse_description" do
    it "uses UTF-16 offsets when an emoji precedes a command" do
      description = JSON.parse(<<-JSON)
        {
          "content": "🚀 Visit example now",
          "commandRuns": [{
            "startIndex": 3,
            "length": 5,
            "onTap": {
              "innertubeCommand": {
                "urlEndpoint": {"url": "https://example.com"}
              }
            }
          }]
        }
        JSON

      expect(parse_description(description, "video-id")).to eq(
        %(🚀 <a href="https://example.com">Visit</a> example now)
      )
    end

    it "uses UTF-16 lengths when an emoji is inside a command" do
      description = JSON.parse(<<-JSON)
        {
          "content": "Open 😀 docs",
          "commandRuns": [{
            "startIndex": 0,
            "length": 7,
            "onTap": {
              "innertubeCommand": {
                "urlEndpoint": {"url": "https://example.com"}
              }
            }
          }]
        }
        JSON

      expect(parse_description(description, "video-id")).to eq(
        %(<a href="https://example.com">Open 😀</a> docs)
      )
    end

    it "escapes complete descriptions without command runs" do
      description = JSON.parse(%({"content":"🚀 <safe> & complete"}))

      expect(parse_description(description, "video-id")).to eq(
        %(🚀 &lt;safe&gt; &amp; complete)
      )
    end
  end
end
