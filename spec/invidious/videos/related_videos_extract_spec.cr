require "../../parsers_helper.cr"

Spectator.describe "parse_related_video" do
  it "extracts the primary channel from collaboration bylines" do
    related = JSON.parse(<<-JSON)
      {
        "videoId": "b2_vBMQmi3M",
        "title": { "simpleText": "Alpha Beta Gamma" },
        "shortBylineText": {
          "runs": [{
            "text": "Primary and Collaborator",
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
                                        "browseId": "UClr4yKwH072yt1nUX29dQGg"
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

    parsed = Invidious::Videos::Parser.parse_related_video(related).not_nil!

    expect(parsed["author"]).to eq("Primary and Collaborator")
    expect(parsed["ucid"]).to eq("UClr4yKwH072yt1nUX29dQGg")
  end
end
