require "../../parsers_helper.cr"

Spectator.describe "YouTube comment descriptions" do
  it "renders inline custom emoji attachments" do
    content = JSON.parse(%({
      "content":"Before:star:after",
      "attachmentRuns":[{
        "startIndex":6,
        "length":6,
        "element":{"type":{"imageType":{"image":{"sources":[{
          "url":"https://lh3.googleusercontent.com/custom=s16-w24-h24-c-k-nd",
          "width":16,
          "height":16
        }]}}}},
        "properties":{"accessibilityProperties":{"label":"star"}}
      }]
    }))

    expect(parse_description(content, "video-id")).to eq(
      %(Before<img class="channel-emoji" alt="star" src="/ggpht/custom=s16-w24-h24-c-k-nd" title="star" width="16" height="16" />after)
    )
  end

  it "proxies ggpht attachments and preserves unsupported attachments" do
    content = JSON.parse(%({
      "content":"one:emoji:two:unknown:three",
      "attachmentRuns":[
        {
          "startIndex":3,
          "length":7,
          "element":{"type":{"imageType":{"image":{"sources":[{
            "url":"https://yt3.ggpht.com/emoji/test?s=16",
            "width":16,
            "height":16
          }]}}}},
          "properties":{"accessibilityProperties":{"label":"emoji"}}
        },
        {
          "startIndex":13,
          "length":9,
          "element":{"type":{"imageType":{"image":{"sources":[{
            "url":"https://example.com/unknown.png",
            "width":16,
            "height":16
          }]}}}},
          "properties":{"accessibilityProperties":{"label":"unknown"}}
        }
      ]
    }))

    expect(parse_description(content, "video-id")).to eq(
      %(one<img class="channel-emoji" alt="emoji" src="/ggpht/emoji/test?s=16" title="emoji" width="16" height="16" />two:unknown:three)
    )
  end
end
