require "../../parsers_helper.cr"

Spectator.describe "parse_related_video" do
  it "parses a related video from a single-creator channel" do
    related = JSON.parse(%({
      "videoId": "BtlWoqWLm9Q",
      "title": {"simpleText": "Secret History #4: How Evil Triumphs"},
      "shortBylineText": {
        "runs": [
          {
            "text": "Predictive History",
            "navigationEndpoint": {
              "clickTrackingParams": "CAA=",
              "commandMetadata": {
                "webCommandMetadata": {
                  "url": "/channel/UC11aHtNnc5bEPLI4jf6mnYg",
                  "webPageType": "WEB_PAGE_TYPE_CHANNEL",
                  "rootVe": 3611,
                  "apiUrl": "/youtubei/v1/browse"
                }
              },
              "browseEndpoint": {
                "browseId": "UC11aHtNnc5bEPLI4jf6mnYg",
                "canonicalBaseUrl": "/@PredictiveHistory"
              }
            }
          }
        ]
      },
      "lengthInSeconds": 7250,
      "shortViewCountText": {"simpleText": "3.2M views"},
      "publishedTimeText": {"simpleText": "11 months ago"}
    }))

    related_video = Invidious::Videos::Parser.parse_related_video(related)

    expect(related_video).not_to be_nil

    expect(related_video.not_nil!["author"].as_s).to eq("Predictive History")
    expect(related_video.not_nil!["ucid"].as_s).to eq("UC11aHtNnc5bEPLI4jf6mnYg")
    expect(related_video.not_nil!["short_view_count"].as_s).to eq("3.2M")
  end

  it "parses a related video with multiple creators (collab)" do
    related = JSON.parse(%({
      "videoId": "Qifsxitq_q4",
      "title": {"simpleText": "Professor Brian Greene: The Threat of AI"},
      "shortBylineText": {
        "runs": [
          {
            "text": "The Diary Of A CEO and World Science Festival",
            "navigationEndpoint": {
              "clickTrackingParams": "CAA=",
              "showDialogCommand": {
                "panelLoadingStrategy": {
                  "inlineContent": {
                    "dialogViewModel": {
                      "customContent": {
                        "listViewModel": {
                          "listItems": [
                            {
                              "listItemViewModel": {
                                "title": {"content": "The Diary Of A CEO"},
                                "rendererContext": {
                                  "commandContext": {
                                    "onTap": {
                                      "innertubeCommand": {
                                        "clickTrackingParams": "CAA=",
                                        "commandMetadata": {
                                          "webCommandMetadata": {
                                            "url": "/channel/UCGq-a57w-aPwyi3pW7XLiHw",
                                            "webPageType": "WEB_PAGE_TYPE_CHANNEL",
                                            "rootVe": 3611,
                                            "apiUrl": "/youtubei/v1/browse"
                                          }
                                        },
                                        "browseEndpoint": {
                                          "browseId": "UCGq-a57w-aPwyi3pW7XLiHw"
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            },
                            {
                              "listItemViewModel": {
                                "title": {"content": "World Science Festival"},
                                "rendererContext": {
                                  "commandContext": {
                                    "onTap": {
                                      "innertubeCommand": {
                                        "browseEndpoint": {
                                          "browseId": "UCshBEKIPwFyXClTBFRwBaBA"
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          ]
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        ]
      },
      "lengthInSeconds": 7400,
      "shortViewCountText": {"simpleText": "1M views"},
      "publishedTimeText": {"simpleText": "4 days ago"}
    }))

    related_video = Invidious::Videos::Parser.parse_related_video(related)

    expect(related_video).not_to be_nil

    expect(related_video.not_nil!["author"].as_s).to eq("The Diary Of A CEO and World Science Festival")
    expect(related_video.not_nil!["ucid"].as_s).to eq("UCGq-a57w-aPwyi3pW7XLiHw")
  end
end
