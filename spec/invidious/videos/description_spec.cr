require "../../parsers_helper.cr"

# Fixtures below are taken verbatim (structurally) from the InnerTube payloads
# that Invidious receives for `commentEntityPayload.properties.content` and for
# video `attributedDescription`s. Custom channel emoji are shipped as an image
# in `attachmentRuns`, with only a `:_EmojiName:` placeholder (followed by
# U+25A1 padding) left behind in `content`. Plain unicode emoji are the opposite:
# they are already in `content` and their attachment run points at YouTube's own
# emoji sprite on `www.youtube.com`, which cannot be served through /ggpht.
private def attachment_run(label : String, start_index : Int32, length : Int32, url : String) : String
  <<-JSON
    {
      "startIndex": #{start_index},
      "length": #{length},
      "element": {
        "type": {
          "imageType": {
            "image": {
              "sources": [{"url": "#{url}", "width": 16, "height": 16}]
            }
          }
        },
        "properties": {
          "accessibilityProperties": {"label": "#{label}"}
        }
      },
      "alignment": "ALIGNMENT_VERTICAL_CENTER"
    }
    JSON
end

private def command_run(start_index : Int32, length : Int32, url : String) : String
  <<-JSON
    {
      "startIndex": #{start_index},
      "length": #{length},
      "onTap": {"innertubeCommand": {"urlEndpoint": {"url": "#{url}"}}}
    }
    JSON
end

CUSTOM_EMOJI_URL = "https://yt3.googleusercontent.com/6-Hzg3v1TFZI9DifzoYrJZYYTsu4quApCRT461xkMjDhaR4xUP8FbsDZe4xIdcTQi_oGPOg4=s16-w24-h24-c-k-nd"
# YouTube's own emoji sprite, served from www.youtube.com (not /ggpht-able).
UNICODE_EMOJI_URL = "https://www.youtube.com/s/gaming/emoji/7ff574f2/emoji_u1f600.png"

Spectator.describe "parse_description" do
  it "returns an empty string for nil content" do
    expect(parse_description(nil, "vid")).to eq("")
  end

  it "returns an empty string for empty content" do
    expect(parse_description(JSON.parse(%({"content": ""})), "vid")).to eq("")
  end

  it "escapes plain content when there are no runs" do
    desc = JSON.parse(%({"content": "a & b <c>"}))
    expect(parse_description(desc, "vid")).to eq("a &amp; b &lt;c&gt;")
  end

  it "renders custom channel emoji as proxied images" do
    content = "hi :_EmojiOne:\u25A1\u25A1 and :_EmojiTwo: end"
    desc = JSON.parse(
      %({"content": "#{content}", "attachmentRuns": [) +
      attachment_run("EmojiOne", 3, 11, CUSTOM_EMOJI_URL) + "," +
      attachment_run("EmojiTwo", 21, 11, CUSTOM_EMOJI_URL) + "]}"
    )

    html = parse_description(desc, "vid").to_s

    expect(html).to eq(
      %(hi ) +
      %(<img alt="EmojiOne" src="/ggpht/6-Hzg3v1TFZI9DifzoYrJZYYTsu4quApCRT461xkMjDhaR4xUP8FbsDZe4xIdcTQi_oGPOg4=s16-w24-h24-c-k-nd" title="EmojiOne" class="channel-emoji" />) +
      %( and ) +
      %(<img alt="EmojiTwo" src="/ggpht/6-Hzg3v1TFZI9DifzoYrJZYYTsu4quApCRT461xkMjDhaR4xUP8FbsDZe4xIdcTQi_oGPOg4=s16-w24-h24-c-k-nd" title="EmojiTwo" class="channel-emoji" />) +
      %( end)
    )
  end

  it "does not leave placeholders or padding behind for custom emoji" do
    content = "hi :_EmojiOne:\u25A1\u25A1"
    desc = JSON.parse(
      %({"content": "#{content}", "attachmentRuns": [) +
      attachment_run("EmojiOne", 3, 11, CUSTOM_EMOJI_URL) + "]}"
    )

    html = parse_description(desc, "vid").to_s

    expect(html).to_not contain(":_EmojiOne:")
    expect(html).to_not contain("\u25A1")
  end

  it "leaves plain unicode emoji alone instead of substituting an image" do
    content = "Smiley: \u{1F600} ok"
    desc = JSON.parse(
      %({"content": "#{content}", "attachmentRuns": [) +
      attachment_run("\u{1F600}", 8, 2, UNICODE_EMOJI_URL) + "]}"
    )

    html = parse_description(desc, "vid").to_s

    expect(html).to eq("Smiley: \u{1F600} ok")
    expect(html).to_not contain("<img")
  end

  it "still renders commandRuns (links and timestamps)" do
    desc = JSON.parse(
      %({"content": "see here", "commandRuns": [) +
      command_run(4, 4, "https://example.com/x") + "]}"
    )

    html = parse_description(desc, "vid").to_s

    expect(html).to contain(%(<a href="https://example.com/x">here</a>))
  end

  it "renders commandRuns and attachmentRuns interleaved in index order" do
    desc = JSON.parse(
      %({"content": "0:48 :_E1: tail", "commandRuns": [) +
      command_run(0, 4, "https://example.com/t") +
      %(], "attachmentRuns": [) +
      attachment_run("E1", 5, 5, CUSTOM_EMOJI_URL) + "]}"
    )

    html = parse_description(desc, "vid").to_s

    expect(html).to contain(%(<a href="https://example.com/t">0:48</a>))
    expect(html).to contain(%(class="channel-emoji" />))
    expect(html).to contain(" tail")
  end
end
