require "../../parsers_helper.cr"

Spectator.describe "parse_description" do
  it "renders custom channel emoji as an image" do
    # Custom emoji only exist in the attachment run; the text content carries
    # the ":shortcode:" placeholder, which must not be shown as-is.
    raw = {
      "content"        => ":face-red-heart-shape: hello",
      "attachmentRuns" => [
        {
          "startIndex" => 0,
          "length"     => 22,
          "element"    => {
            "type" => {
              "imageType" => {
                "image" => {
                  "sources" => [
                    {"url" => "https://lh3.googleusercontent.com/abc=s16-w24-h24-c-k-nd", "width" => 16, "height" => 16},
                  ],
                },
              },
            },
            "properties" => {
              "accessibilityProperties" => {"label" => "face-red-heart-shape"},
            },
          },
        },
      ],
    }

    result = parse_description(JSON.parse(raw.to_json), "")

    expect(result).to eq(
      %(<img alt="face-red-heart-shape" src="/ggpht/abc=s16-w24-h24-c-k-nd" ) +
      %(title="face-red-heart-shape" width="16" height="16" class="channel-emoji" /> hello)
    )
  end

  it "leaves standard unicode emoji untouched" do
    # Standard emoji also come with an attachment run, but the text content is
    # already the emoji character, so it must be kept as text.
    raw = {
      "content"        => "Nice sharing 🎉",
      "attachmentRuns" => [
        {
          "startIndex" => 13,
          "length"     => 2,
          "element"    => {
            "type" => {
              "imageType" => {
                "image" => {
                  "sources" => [
                    {"url" => "https://www.youtube.com/s/gaming/emoji/7ff574f2/emoji_u1f389.png", "width" => 16, "height" => 16},
                  ],
                },
              },
            },
            "properties" => {
              "accessibilityProperties" => {"label" => "🎉"},
            },
          },
        },
      ],
    }

    result = parse_description(JSON.parse(raw.to_json), "")

    expect(result).to eq("Nice sharing 🎉")
  end

  it "keeps text offsets correct when an emoji precedes other content" do
    # The emoji run is consumed from the same iterator as the surrounding
    # text, so a wrong length here would shift everything after it.
    raw = {
      "content"        => "a:face-red-heart-shape:b",
      "attachmentRuns" => [
        {
          "startIndex" => 1,
          "length"     => 22,
          "element"    => {
            "type" => {
              "imageType" => {
                "image" => {
                  "sources" => [
                    {"url" => "https://lh3.googleusercontent.com/abc", "width" => 16, "height" => 16},
                  ],
                },
              },
            },
            "properties" => {
              "accessibilityProperties" => {"label" => "face-red-heart-shape"},
            },
          },
        },
      ],
    }

    result = parse_description(JSON.parse(raw.to_json), "")

    expect(result).to start_with("a<img ")
    expect(result).to end_with("/>b")
  end
end
