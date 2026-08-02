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

    it "continues to count basic multilingual plane characters once" do
      description = JSON.parse(<<-JSON)
        {
          "content": "Café link",
          "commandRuns": [{
            "startIndex": 5,
            "length": 4,
            "onTap": {
              "innertubeCommand": {
                "urlEndpoint": {"url": "https://example.com"}
              }
            }
          }]
        }
        JSON

      expect(parse_description(description, "video-id")).to eq(
        %(Café <a href="https://example.com">link</a>)
      )
    end

    it "escapes HTML around and inside commands" do
      description = JSON.parse(<<-JSON)
        {
          "content": "🚀 <click> & end",
          "commandRuns": [{
            "startIndex": 3,
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
        %(🚀 <a href="https://example.com">&lt;click&gt;</a> &amp; end)
      )
    end
  end
end
