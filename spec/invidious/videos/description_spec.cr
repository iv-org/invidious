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
end
