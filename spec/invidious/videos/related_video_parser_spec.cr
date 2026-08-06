require "../../parsers_helper.cr"

Spectator.describe "parse_related_video" do
  it "extracts a channel id from a multi-creator collaborator dialog" do
    related = JSON.parse(<<-JSON)
      {
        "videoId": "dbVdnL6HWOg",
        "title": {"simpleText": "Example video"},
        "shortBylineText": {
          "runs": [{
            "text": "Piers Morgan Uncensored y ProfSteveKeen",
            "navigationEndpoint": {
              "showDialogCommand": {
                "panelLoadingStrategy": {
                  "inlineContent": {
                    "dialogViewModel": {
                      "customContent": {
                        "listViewModel": {
                          "listItems": [{
                            "listItemViewModel": {
                              "rendererContext": {
                                "commandContext": {
                                  "onTap": {
                                    "innertubeCommand": {
                                      "browseEndpoint": {
                                        "browseId": "UCatt7TBjfBkiJWx8khav_Gg"
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          }]
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

    parsed = Invidious::Videos::Parser.parse_related_video(related)

    expect(parsed).to_not be_nil
    expect(parsed.not_nil!["author"]).to eq("Piers Morgan Uncensored y ProfSteveKeen")
    expect(parsed.not_nil!["ucid"]).to eq("UCatt7TBjfBkiJWx8khav_Gg")
  end

  it "keeps extracting a direct channel id" do
    related = JSON.parse(<<-JSON)
      {
        "videoId": "example",
        "title": {"simpleText": "Example video"},
        "shortBylineText": {
          "runs": [{
            "text": "Example channel",
            "navigationEndpoint": {
              "browseEndpoint": {"browseId": "UCexample"}
            }
          }]
        }
      }
      JSON

    parsed = Invidious::Videos::Parser.parse_related_video(related)

    expect(parsed).to_not be_nil
    expect(parsed.not_nil!["ucid"]).to eq("UCexample")
  end
end
