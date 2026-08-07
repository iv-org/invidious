require "json"
require "uri"

require "spectator"

require "../../../src/invidious/helpers/utils"
require "../../../src/invidious/videos/description"

Spectator.describe "parse_description" do
  it "renders custom emojis using the current YouTube attachment-run schema" do
    description = JSON.parse(%({
      "content":":face-red-heart-shape::face-orange-biting-nails:",
      "attachmentRuns":[
        {
          "startIndex":0,
          "length":22,
          "element":{"type":{"imageType":{"image":{"sources":[{
            "url":"https://lh3.googleusercontent.com/red-heart=s16-w24-h24-c-k-nd",
            "width":16,
            "height":16
          }]}}}},
          "properties":{"accessibilityProperties":{"label":"face-red-heart-shape"}}
        },
        {
          "startIndex":22,
          "length":26,
          "element":{"type":{"imageType":{"image":{"sources":[{
            "url":"https://lh3.googleusercontent.com/biting-nails=s16-w24-h24-c-k-nd",
            "width":16,
            "height":16
          }]}}}},
          "properties":{"accessibilityProperties":{"label":"face-orange-biting-nails"}}
        }
      ]
    }))

    expect(parse_description(description, "video-id")).to eq(
      %(<img alt="face-red-heart-shape" src="/ggpht/red-heart=s16-w24-h24-c-k-nd" title="face-red-heart-shape" width="16" height="16" class="channel-emoji" />) +
      %(<img alt="face-orange-biting-nails" src="/ggpht/biting-nails=s16-w24-h24-c-k-nd" title="face-orange-biting-nails" width="16" height="16" class="channel-emoji" />)
    )
  end

  it "keeps command runs and UTF-16 attachment indexes aligned" do
    description = JSON.parse(%({
      "content":"😀visit :custom:",
      "commandRuns":[{
        "startIndex":2,
        "length":5,
        "onTap":{"innertubeCommand":{"urlEndpoint":{"url":"https://example.com"}}}
      }],
      "attachmentRuns":[{
        "startIndex":8,
        "length":8,
        "element":{"type":{"imageType":{"image":{"sources":[{
          "url":"https://yt3.ggpht.com/custom=s16",
          "width":16,
          "height":16
        }]}}}},
        "properties":{"accessibilityProperties":{"label":"custom"}}
      }]
    }))

    expect(parse_description(description, "video-id")).to eq(
      %(😀<a href="https://example.com">visit</a> <img alt="custom" src="/ggpht/custom=s16" title="custom" width="16" height="16" class="channel-emoji" />)
    )
  end

  it "preserves the escaped shortcode when an attachment source is unsupported" do
    description = JSON.parse(%({
      "content":"before <:custom:> after",
      "attachmentRuns":[{
        "startIndex":8,
        "length":8,
        "element":{"type":{"imageType":{"image":{"sources":[{
          "url":"https://example.com/custom.png",
          "width":16,
          "height":16
        }]}}}},
        "properties":{"accessibilityProperties":{"label":"custom"}}
      }]
    }))

    expect(parse_description(description, "video-id")).to eq("before &lt;:custom:&gt; after")
  end

  it "preserves the escaped shortcode when an attachment source URL is invalid" do
    description = JSON.parse(%({
      "content":"before <:custom:> after",
      "attachmentRuns":[{
        "startIndex":8,
        "length":8,
        "element":{"type":{"imageType":{"image":{"sources":[{
          "url":"https://lh3.googleusercontent.com:invalid/custom.png",
          "width":16,
          "height":16
        }]}}}},
        "properties":{"accessibilityProperties":{"label":"custom"}}
      }]
    }))

    expect(parse_description(description, "video-id")).to eq("before &lt;:custom:&gt; after")
  end

  it "escapes attachment labels before inserting them into HTML" do
    description = JSON.parse(%({
      "content":":custom:",
      "attachmentRuns":[{
        "startIndex":0,
        "length":8,
        "element":{"type":{"imageType":{"image":{"sources":[{
          "url":"https://lh3.googleusercontent.com/custom=s16",
          "width":16,
          "height":16
        }]}}}},
        "properties":{"accessibilityProperties":{"label":"custom\\u0022 onerror=\\u0022alert(1)"}}
      }]
    }))

    expect(parse_description(description, "video-id")).to eq(
      %(<img alt="custom&quot; onerror=&quot;alert(1)" src="/ggpht/custom=s16" title="custom&quot; onerror=&quot;alert(1)" width="16" height="16" class="channel-emoji" />)
    )
  end

  it "does not render zero-length graphical attachments" do
    description = JSON.parse(%({
      "content":"plain text",
      "attachmentRuns":[{
        "startIndex":0,
        "length":0,
        "element":{"type":{"imageType":{"image":{"sources":[{
          "url":"https://lh3.googleusercontent.com/badge=s16",
          "width":16,
          "height":16
        }]}}}},
        "properties":{"accessibilityProperties":{"label":"badge"}}
      }]
    }))

    expect(parse_description(description, "video-id")).to eq("plain text")
  end
end
