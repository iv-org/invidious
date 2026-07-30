require "../../parsers_helper.cr"

Spectator.describe Invidious::Videos::Parser do
  it "uses the primary owner channel for collaborative related videos" do
    related = JSON.parse(<<-JSON)
      {
        "videoId": "b2_vBMQmi3M",
        "title": {"simpleText": "Collaborative video"},
        "shortBylineText": {
          "runs": [
            {
              "text": "D/V and FΛDE",
              "navigationEndpoint": {
                "showDialogCommand": {
                  "panelLoadingStrategy": {
                    "inlineContent": {}
                  }
                }
              }
            }
          ]
        },
        "channelThumbnailSupportedRenderers": {
          "channelThumbnailWithLinkRenderer": {
            "navigationEndpoint": {
              "browseEndpoint": {
                "browseId": "UClr4yKwH072yt1nUX29dQGg",
                "canonicalBaseUrl": "/@DslashV"
              }
            }
          }
        }
      }
      JSON

    result = Invidious::Videos::Parser.parse_related_video(related).not_nil!

    expect(result["author"].as_s).to eq("D/V and FΛDE")
    expect(result["ucid"].as_s).to eq("UClr4yKwH072yt1nUX29dQGg")
  end
end
