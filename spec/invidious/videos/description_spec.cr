require "../../parsers_helper.cr"

Spectator.describe "parse_description" do
  it "renders YouTube attachment runs as images" do
    description = JSON.parse(<<-JSON)
      {
        "content": ":face-red-heart-shape::face-orange-biting-nails:",
        "attachmentRuns": [
          {
            "startIndex": 0,
            "length": 22,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [{
                      "url": "https://lh3.googleusercontent.com/emoji-red=s16-w24-h24-c-k-nd",
                      "width": 16,
                      "height": 16
                    }]
                  }
                }
              }
            },
            "properties": {
              "accessibilityProperties": {"label": "face-red-heart-shape"}
            }
          },
          {
            "startIndex": 22,
            "length": 26,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [{
                      "url": "https://lh3.googleusercontent.com/emoji-orange=s16-w24-h24-c-k-nd",
                      "width": 16,
                      "height": 16
                    }]
                  }
                }
              }
            },
            "properties": {
              "accessibilityProperties": {"label": "face-orange-biting-nails"}
            }
          }
        ]
      }
    JSON

    html = parse_description(description, "Gy3bmuzmWMM").not_nil!

    expect(html).to eq(
      %(<img alt="face-red-heart-shape" src="/ggpht/emoji-red=s16-w24-h24-c-k-nd" title="face-red-heart-shape" width="16" height="16" class="channel-emoji" />) +
      %(<img alt="face-orange-biting-nails" src="/ggpht/emoji-orange=s16-w24-h24-c-k-nd" title="face-orange-biting-nails" width="16" height="16" class="channel-emoji" />)
    )
  end

  it "preserves attachment text when image data is unavailable" do
    description = JSON.parse(<<-JSON)
      {
        "content": "hello:custom-emoji:",
        "attachmentRuns": [{
          "startIndex": 5,
          "length": 14,
          "element": {"type": {"imageType": {"image": {}}}}
        }]
      }
    JSON

    expect(parse_description(description, "video-id")).to eq("hello:custom-emoji:")
  end

  it "preserves attachment text when the image host is unsupported" do
    description = JSON.parse(<<-JSON)
      {
        "content": "one:custom-emoji:two",
        "attachmentRuns": [{
          "startIndex": 3,
          "length": 14,
          "element": {
            "type": {
              "imageType": {
                "image": {
                  "sources": [{"url": "https://example.com/custom.png", "width": 16, "height": 16}]
                }
              }
            }
          },
          "properties": {"accessibilityProperties": {"label": "custom-emoji"}}
        }]
      }
    JSON

    expect(parse_description(description, "video-id")).to eq("one:custom-emoji:two")
  end

  it "renders attachments nested in command runs" do
    description = JSON.parse(<<-JSON)
      {
        "content": "abcd",
        "commandRuns": [{
          "startIndex": 0,
          "length": 4,
          "onTap": {"innertubeCommand": {"watchEndpoint": {"videoId": "linked-video"}}}
        }],
        "attachmentRuns": [
          {
            "startIndex": 0,
            "length": 0,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [{"url": "https://lh3.googleusercontent.com/emoji-start=s16", "width": 16, "height": 16}]
                  }
                }
              }
            },
            "properties": {"accessibilityProperties": {"label": "emoji-at-start"}}
          },
          {
            "startIndex": 2,
            "length": 0,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [{"url": "https://lh3.googleusercontent.com/emoji-inside=s16", "width": 16, "height": 16}]
                  }
                }
              }
            },
            "properties": {"accessibilityProperties": {"label": "emoji-inside"}}
          }
        ]
      }
    JSON

    expect(parse_description(description, "video-id")).to eq(
      %(<a href="/watch?v=linked-video">) +
      %(<img alt="emoji-at-start" src="/ggpht/emoji-start=s16" title="emoji-at-start" width="16" height="16" class="channel-emoji" />) +
      "ab" +
      %(<img alt="emoji-inside" src="/ggpht/emoji-inside=s16" title="emoji-inside" width="16" height="16" class="channel-emoji" />) +
      "cd</a>"
    )
  end

  it "assigns boundary attachments to only the following command run" do
    description = JSON.parse(<<-JSON)
      {
        "content": "abcd",
        "commandRuns": [
          {
            "startIndex": 0,
            "length": 2,
            "onTap": {"innertubeCommand": {"watchEndpoint": {"videoId": "first-video"}}}
          },
          {
            "startIndex": 2,
            "length": 2,
            "onTap": {"innertubeCommand": {"watchEndpoint": {"videoId": "second-video"}}}
          }
        ],
        "attachmentRuns": [{
          "startIndex": 2,
          "length": 0,
          "element": {
            "type": {
              "imageType": {
                "image": {
                  "sources": [{"url": "https://lh3.googleusercontent.com/emoji-boundary=s16", "width": 16, "height": 16}]
                }
              }
            }
          },
          "properties": {"accessibilityProperties": {"label": "emoji-boundary"}}
        }]
      }
    JSON

    expect(parse_description(description, "video-id")).to eq(
      %(<a href="/watch?v=first-video">ab</a>) +
      %(<a href="/watch?v=second-video"><img alt="emoji-boundary" src="/ggpht/emoji-boundary=s16" title="emoji-boundary" width="16" height="16" class="channel-emoji" />cd</a>)
    )
  end
end
