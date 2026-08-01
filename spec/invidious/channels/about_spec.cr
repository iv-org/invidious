require "../../../src/invidious/exceptions"
require "../../spec_helper"

Spectator.describe "extract_auto_generated_channel_header" do
  it "parses the current pageHeaderRenderer shape" do
    initdata = JSON.parse(<<-JSON).as_h
      {
        "header": {
          "pageHeaderRenderer": {
            "pageTitle": "Gaming",
            "content": {
              "pageHeaderViewModel": {
                "title": {
                  "dynamicTextViewModel": {
                    "text": {"content": "Gaming"}
                  }
                },
                "animatedImage": {
                  "contentPreviewImageViewModel": {
                    "image": {
                      "sources": [
                        {"url": "//yt3.example/avatar-48", "width": 48, "height": 48}
                      ]
                    }
                  }
                }
              }
            }
          }
        }
      }
      JSON

    header = extract_auto_generated_channel_header(initdata, "UCOpNcN46UbXVtpKMrmU4Abg")

    expect(header[:author]).to eq("Gaming")
    expect(header[:author_url]).to eq("https://www.youtube.com/channel/UCOpNcN46UbXVtpKMrmU4Abg")
    expect(header[:author_thumbnail]).to eq("//yt3.example/avatar-48")
    expect(header[:banner]).to be_nil
    expect(header[:description_node]).to be_nil
    expect(header[:tags]).to be_empty
    expect(header[:is_family_friendly]).to be_true
  end

  it "preserves the legacy interactiveTabbedHeaderRenderer shape" do
    initdata = JSON.parse(<<-JSON).as_h
      {
        "header": {
          "interactiveTabbedHeaderRenderer": {
            "title": {"simpleText": "Legacy gaming"},
            "boxArt": {
              "thumbnails": [
                {"url": "https://yt3.example/legacy-avatar"}
              ]
            },
            "banner": {
              "thumbnails": [
                {"url": "https://yt3.example/legacy-banner"}
              ]
            },
            "description": {"simpleText": "Legacy description"},
            "badges": [
              {"metadataBadgeRenderer": {"label": "Verified"}}
            ]
          }
        },
        "microformat": {
          "microformatDataRenderer": {
            "urlCanonical": "https://www.youtube.com/channel/legacy",
            "familySafe": false
          }
        }
      }
      JSON

    header = extract_auto_generated_channel_header(initdata, "legacy")

    expect(header[:author]).to eq("Legacy gaming")
    expect(header[:author_url]).to eq("https://www.youtube.com/channel/legacy")
    expect(header[:author_thumbnail]).to eq("https://yt3.example/legacy-avatar")
    expect(header[:banner]).to eq("https://yt3.example/legacy-banner")
    expect(header[:description_node].try &.as_s).to eq("Legacy description")
    expect(header[:tags]).to eq(["Verified"])
    expect(header[:is_family_friendly]).to be_false
  end
end
