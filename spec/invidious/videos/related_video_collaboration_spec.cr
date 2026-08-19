require "../../parsers_helper.cr"

Spectator.describe "parse_related_video" do
  it "extracts the channel of a video published as a collaboration" do
    # A video published as a collaboration between two channels. Its byline
    # carries no "browseEndpoint"; it opens a "Collaborators" dialog instead,
    # and the channel of each collaborator sits inside that dialog.
    #
    # See: https://github.com/iv-org/invidious/issues/5722
    related = JSON.parse(<<-JSON)
      {
        "videoId": "dbVdnL6HWOg",
        "title": { "simpleText": "Professor Jiang Debates Iran War, Trump And China Ties" },
        "lengthInSeconds": 2241,
        "shortViewCountText": { "simpleText": "1M views" },
        "publishedTimeText": { "simpleText": "3 months ago" },
        "shortBylineText": {
          "runs": [
            {
              "text": "Piers Morgan Uncensored and ProfSteveKeen",
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
                                  "title": { "content": "Piers Morgan Uncensored" },
                                  "rendererContext": {
                                    "commandContext": {
                                      "onTap": {
                                        "innertubeCommand": {
                                          "browseEndpoint": { "browseId": "UCatt7TBjfBkiJWx8khav_Gg" }
                                        }
                                      }
                                    }
                                  }
                                }
                              },
                              {
                                "listItemViewModel": {
                                  "title": { "content": "ProfSteveKeen" },
                                  "rendererContext": {
                                    "commandContext": {
                                      "onTap": {
                                        "innertubeCommand": {
                                          "browseEndpoint": { "browseId": "UCM1ubsbE-tG9ru61mc3zX8A" }
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
        }
      }
      JSON

    parsed = Invidious::Videos::Parser.parse_related_video(related).not_nil!

    expect(parsed["ucid"].as_s).to eq("UCatt7TBjfBkiJWx8khav_Gg")
    expect(parsed["author"].as_s).to eq("Piers Morgan Uncensored and ProfSteveKeen")
  end

  it "keeps extracting the channel of a single author video" do
    related = JSON.parse(<<-JSON)
      {
        "videoId": "_g4l7YkDQwA",
        "title": { "simpleText": "The Diary Of A CEO episode" },
        "lengthInSeconds": 1337,
        "shortViewCountText": { "simpleText": "2.1M views" },
        "publishedTimeText": { "simpleText": "1 month ago" },
        "shortBylineText": {
          "runs": [
            {
              "text": "The Diary Of A CEO",
              "navigationEndpoint": {
                "browseEndpoint": { "browseId": "UCGq-a57w-aPwyi3pW7XLiHw" }
              }
            }
          ]
        }
      }
      JSON

    parsed = Invidious::Videos::Parser.parse_related_video(related).not_nil!

    expect(parsed["ucid"].as_s).to eq("UCGq-a57w-aPwyi3pW7XLiHw")
    expect(parsed["author"].as_s).to eq("The Diary Of A CEO")
  end
end
