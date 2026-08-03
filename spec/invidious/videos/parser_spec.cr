require "../../parsers_helper"

Spectator.describe Invidious::Videos::Parser do
  describe ".parse_related_video" do
    it "uses the first creator channel for a collaborative byline" do
      related = JSON.parse(%(
        {
          "videoId": "BTJGr78-zyw",
          "title": {
            "simpleText": "Collaborative video"
          },
          "shortBylineText": {
            "runs": [
              {
                "text": "The Diary Of A CEO and Predictive History",
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
                                    "rendererContext": {
                                      "commandContext": {
                                        "onTap": {
                                          "innertubeCommand": {
                                            "browseEndpoint": {
                                              "browseId": "UC11aHtNnc5bEPLI4jf6mnYg"
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
          }
        }
      ))

      parsed = Invidious::Videos::Parser.parse_related_video(related).not_nil!

      expect(parsed["author"].as_s).to eq("The Diary Of A CEO and Predictive History")
      expect(parsed["ucid"].as_s).to eq("UCGq-a57w-aPwyi3pW7XLiHw")
    end
  end
end
