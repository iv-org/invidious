require "../../../src/invidious/exceptions"
require "../../spec_helper"

Spectator.describe "extract_auto_generated_channel_header" do
  it "parses the carouselHeaderRenderer shape" do
    # ex: https://www.youtube.com/channel/UCEgdi0XIXXZ-qJOFPf4JSKw (Sports)
    initdata = JSON.parse(<<-JSON).as_h
      {
        "header": {
          "carouselHeaderRenderer": {
            "contents": [
              {
                "carouselItemRenderer": {
                  "carouselItems": []
                }
              },
              {
                "topicChannelDetailsRenderer": {
                  "title": {"simpleText": "Sports"},
                  "avatar": {
                    "thumbnails": [
                      {"url": "//yt3.example/topic-avatar", "width": 88, "height": 88}
                    ]
                  },
                  "subtitle": {"simpleText": "74.3M subscribers"}
                }
              }
            ]
          }
        }
      }
      JSON

    header = extract_auto_generated_channel_header(initdata, "UCEgdi0XIXXZ-qJOFPf4JSKw")

    expect(header[:author]).to eq("Sports")
    expect(header[:author_url]).to eq("https://www.youtube.com/channel/UCEgdi0XIXXZ-qJOFPf4JSKw")
    expect(header[:author_thumbnail]).to eq("//yt3.example/topic-avatar")
    expect(header[:banner]).to be_nil
    expect(header[:description_node]).to be_nil
    expect(header[:tags]).to be_empty
    expect(header[:is_family_friendly]).to be_true
  end

  it "finds the topic details regardless of their position in the carousel" do
    initdata = JSON.parse(<<-JSON).as_h
      {
        "header": {
          "carouselHeaderRenderer": {
            "contents": [
              {
                "topicChannelDetailsRenderer": {
                  "title": {"simpleText": "Sports"},
                  "avatar": {"thumbnails": [{"url": "//yt3.example/first"}]}
                }
              },
              {
                "carouselItemRenderer": {"carouselItems": []}
              }
            ]
          }
        }
      }
      JSON

    header = extract_auto_generated_channel_header(initdata, "UCEgdi0XIXXZ-qJOFPf4JSKw")

    expect(header[:author]).to eq("Sports")
    expect(header[:author_thumbnail]).to eq("//yt3.example/first")
  end

  it "falls back to the ucid when the carousel carries no topic details" do
    initdata = JSON.parse(<<-JSON).as_h
      {
        "header": {
          "carouselHeaderRenderer": {
            "contents": [
              {"carouselItemRenderer": {"carouselItems": []}}
            ]
          }
        }
      }
      JSON

    header = extract_auto_generated_channel_header(initdata, "UCEgdi0XIXXZ-qJOFPf4JSKw")

    expect(header[:author]).to eq("UCEgdi0XIXXZ-qJOFPf4JSKw")
    expect(header[:author_thumbnail]).to eq("")
  end

  it "parses the current pageHeaderRenderer shape" do
    # ex: https://www.youtube.com/channel/UCOpNcN46UbXVtpKMrmU4Abg (Gaming)
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
                        {"url": "//yt3.example/avatar", "width": 48, "height": 48}
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
    expect(header[:author_thumbnail]).to eq("//yt3.example/avatar")
  end

  it "preserves the legacy interactiveTabbedHeaderRenderer shape" do
    initdata = JSON.parse(<<-JSON).as_h
      {
        "header": {
          "interactiveTabbedHeaderRenderer": {
            "title": {"simpleText": "Legacy gaming"},
            "boxArt": {"thumbnails": [{"url": "//yt3.example/legacy-avatar"}]},
            "banner": {"thumbnails": [{"url": "//yt3.example/legacy-banner"}]},
            "description": {"simpleText": "A legacy description"},
            "badges": [
              {"metadataBadgeRenderer": {"label": "Gaming"}}
            ]
          }
        },
        "microformat": {
          "microformatDataRenderer": {
            "urlCanonical": "https://www.youtube.com/channel/UCLegacy"
          }
        }
      }
      JSON

    header = extract_auto_generated_channel_header(initdata, "UCLegacy")

    expect(header[:author]).to eq("Legacy gaming")
    expect(header[:author_url]).to eq("https://www.youtube.com/channel/UCLegacy")
    expect(header[:author_thumbnail]).to eq("//yt3.example/legacy-avatar")
    expect(header[:banner]).to eq("//yt3.example/legacy-banner")
    expect(header[:tags]).to eq(["Gaming"])
  end

  it "keeps an explicit familySafe: false" do
    initdata = JSON.parse(<<-JSON).as_h
      {
        "header": {
          "pageHeaderRenderer": {"pageTitle": "Gaming"}
        },
        "microformat": {
          "microformatDataRenderer": {"familySafe": false}
        }
      }
      JSON

    header = extract_auto_generated_channel_header(initdata, "UCOpNcN46UbXVtpKMrmU4Abg")

    expect(header[:is_family_friendly]).to be_false
  end

  it "raises when the header shape is unknown" do
    initdata = JSON.parse(<<-JSON).as_h
      {
        "header": {
          "someFutureHeaderRenderer": {}
        }
      }
      JSON

    expect do
      extract_auto_generated_channel_header(initdata, "UCUnknown")
    end.to raise_error(InfoException)
  end
end

Spectator.describe "extract_topic_channel_details" do
  it "returns nil when the payload carries no carousel header" do
    initdata = JSON.parse(<<-JSON).as_h
      {
        "header": {
          "pageHeaderRenderer": {"pageTitle": "Gaming"}
        }
      }
      JSON

    expect(extract_topic_channel_details(initdata)).to be_nil
  end

  it "returns nil when the carousel carries no topic details" do
    initdata = JSON.parse(<<-JSON).as_h
      {
        "header": {
          "carouselHeaderRenderer": {
            "contents": [
              {"carouselItemRenderer": {"carouselItems": []}}
            ]
          }
        }
      }
      JSON

    expect(extract_topic_channel_details(initdata)).to be_nil
  end

  it "exposes the subscriber count carried by the subtitle" do
    # `subscriberCountText` is part of the renderer but comes back null, so the
    # count is only available as free text in the subtitle.
    # ex: https://www.youtube.com/channel/UCEgdi0XIXXZ-qJOFPf4JSKw (Sports)
    initdata = JSON.parse(<<-JSON).as_h
      {
        "header": {
          "carouselHeaderRenderer": {
            "contents": [
              {"carouselItemRenderer": {"carouselItems": []}},
              {
                "topicChannelDetailsRenderer": {
                  "title": {"simpleText": "Sports"},
                  "avatar": {"thumbnails": [{"url": "//yt3.example/topic-avatar"}]},
                  "subscriberCountText": null,
                  "subtitle": {"simpleText": "74.3M subscribers"}
                }
              }
            ]
          }
        }
      }
      JSON

    details = extract_topic_channel_details(initdata)

    expect(details).not_to be_nil
    sub_text = details.not_nil!.dig("subtitle", "simpleText").as_s
    expect(sub_text).to eq("74.3M subscribers")
    expect(short_text_to_number(sub_text.split(" ")[0])).to eq(74_300_000_i64)
  end
end
