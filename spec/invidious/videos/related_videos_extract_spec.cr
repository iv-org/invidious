require "../../parsers_helper.cr"

Spectator.describe "parse_related_video" do
  it "uses a directly linked channel ID" do
    related = JSON.parse(<<-JSON)
      {
        "videoId": "video-id",
        "title": {"simpleText": "Video title"},
        "shortBylineText": {
          "runs": [{
            "text": "Channel name",
            "navigationEndpoint": {
              "browseEndpoint": {"browseId": "UC-direct"}
            }
          }]
        }
      }
      JSON

    video = Invidious::Videos::Parser.parse_related_video(related).not_nil!

    expect(video["author"]).to eq("Channel name")
    expect(video["ucid"]).to eq("UC-direct")
  end

  it "links a collaboration byline to the first listed collaborator" do
    related = JSON.parse(<<-JSON)
      {
        "videoId": "collaboration-id",
        "title": {"simpleText": "Collaboration"},
        "shortBylineText": {
          "runs": [{
            "text": "First Channel and Second Channel",
            "navigationEndpoint": {
              "showDialogCommand": {
                "panelLoadingStrategy": {
                  "inlineContent": {
                    "dialogViewModel": {
                      "customContent": {
                        "listViewModel": {
                          "listItems": [
                            {
                              "listItemViewModel": {
                                "rendererContext": {
                                  "commandContext": {
                                    "onTap": {
                                      "innertubeCommand": {
                                        "browseEndpoint": {"browseId": "UC-first"}
                                      }
                                    }
                                  }
                                }
                              }
                            },
                            {
                              "listItemViewModel": {
                                "rendererContext": {
                                  "commandContext": {
                                    "onTap": {
                                      "innertubeCommand": {
                                        "browseEndpoint": {"browseId": "UC-second"}
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
          }]
        }
      }
      JSON

    video = Invidious::Videos::Parser.parse_related_video(related).not_nil!

    expect(video["author"]).to eq("First Channel and Second Channel")
    expect(video["ucid"]).to eq("UC-first")
  end

  it "keeps the channel ID empty when no destination is available" do
    related = JSON.parse(<<-JSON)
      {
        "videoId": "unlinked-id",
        "title": {"simpleText": "Unlinked video"},
        "shortBylineText": {"runs": [{"text": "Unlinked author"}]}
      }
      JSON

    video = Invidious::Videos::Parser.parse_related_video(related).not_nil!

    expect(video["author"]).to eq("Unlinked author")
    expect(video["ucid"]).to eq("")
  end
end
