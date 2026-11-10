require "../../parsers_helper.cr"

Spectator.describe "parse_related_video collaboration links" do
  it "keeps an ordinary linked channel unchanged" do
    related = JSON.parse(<<-JSON)
      {
        "videoId": "single-video",
        "title": {"simpleText": "Single creator"},
        "shortBylineText": {"runs": [
          {"text": "Single Creator", "navigationEndpoint": {
            "browseEndpoint": {"browseId": "UC-single"}
          }}
        ]}
      }
      JSON

    result = Invidious::Videos::Parser.parse_related_video(related).not_nil!
    expect(result["author"].as_s).to eq("Single Creator")
    expect(result["ucid"].as_s).to eq("UC-single")
    expect(result.has_key?("author_list")).to be_false
  end

  it "uses the first available browse ID when the first run has none" do
    related = JSON.parse(<<-JSON)
      {
        "videoId": "multi-run-video",
        "title": {"simpleText": "Split byline"},
        "shortBylineText": {"runs": [
          {"text": "A and B"},
          {"text": "Creator B", "navigationEndpoint": {
            "browseEndpoint": {"browseId": "UC-second"}
          }}
        ]}
      }
      JSON

    result = Invidious::Videos::Parser.parse_related_video(related).not_nil!
    expect(result["author"].as_s).to eq("A and B")
    expect(result["ucid"].as_s).to eq("UC-second")
    expect(result.has_key?("author_list")).to be_false
  end

  it "preserves the combined label and links both collaborators" do
    related = JSON.parse(<<-JSON)
      {
        "videoId": "collaboration-video",
        "title": {"simpleText": "Collaboration"},
        "shortBylineText": {"runs": [{
          "text": "Alice and Bob",
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
                              "title": {"content": "Alice"},
                              "rendererContext": {
                                "commandContext": {
                                  "onTap": {
                                    "innertubeCommand": {
                                      "browseEndpoint": {"browseId": "UC-alice"}
                                    }
                                  }
                                }
                              }
                            }
                          },
                          {
                            "listItemViewModel": {
                              "title": {
                                "content": "Bob",
                                "attachmentRuns": [{
                                  "element": {
                                    "type": {"imageType": {
                                      "image": {"sources": [{
                                        "clientResource": {"imageName": "CHECK_CIRCLE_FILLED"}
                                      }]}
                                    }}
                                  }
                                }]
                              },
                              "rendererContext": {
                                "commandContext": {
                                  "onTap": {
                                    "innertubeCommand": {
                                      "browseEndpoint": {"browseId": "UC-bob"}
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
        }]}
      }
      JSON

    result = Invidious::Videos::Parser.parse_related_video(related).not_nil!
    expect(result["author"].as_s).to eq("Alice and Bob")
    expect(result["ucid"].as_s).to eq("UC-alice")

    authors = JSON.parse(result["author_list"].as_s).as_a
    expect(authors.size).to eq(2)
    expect(authors[0]["username"].as_s).to eq("Alice")
    expect(authors[0]["ucid"].as_s).to eq("UC-alice")
    expect(authors[0]["author_verified"].as_s).to eq("false")
    expect(authors[1]["username"].as_s).to eq("Bob")
    expect(authors[1]["ucid"].as_s).to eq("UC-bob")
    expect(authors[1]["author_verified"].as_s).to eq("true")
  end

  it "ignores incomplete collaborator metadata and preserves a safe fallback" do
    related = JSON.parse(<<-JSON)
      {
        "videoId": "incomplete-collaboration",
        "title": {"simpleText": "Unknown channels"},
        "shortBylineText": {"runs": [{
          "text": "Creators with missing links",
          "navigationEndpoint": {
            "showDialogCommand": {
              "panelLoadingStrategy": {
                "inlineContent": {
                  "dialogViewModel": {
                    "customContent": {"listViewModel": {
                      "listItems": [
                        {"listItemViewModel": {"title": {"content": "No destination"}}},
                        {"listItemViewModel": {
                          "title": {"content": "Not a channel"},
                          "rendererContext": {"commandContext": {"onTap": {
                            "innertubeCommand": {"browseEndpoint": {"browseId": "not-channel"}}
                          }}}
                        }}
                      ]
                    }}
                  }
                }
              }
            }
          }
        }]}
      }
      JSON

    result = Invidious::Videos::Parser.parse_related_video(related).not_nil!
    expect(result["author"].as_s).to eq("Creators with missing links")
    expect(result["ucid"].as_s).to eq("")
    expect(result.has_key?("author_list")).to be_false
  end

  it "ignores duplicate collaborator IDs" do
    related = JSON.parse(<<-JSON)
      {
        "videoId": "duplicate-collaboration",
        "title": {
          "simpleText": "Duplicated"
        },
        "shortBylineText": {
          "runs": [
            {
              "text": "Alice and Alice",
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
                                  "title": {
                                    "content": "Alice"
                                  },
                                  "rendererContext": {
                                    "commandContext": {
                                      "onTap": {
                                        "innertubeCommand": {
                                          "browseEndpoint": {
                                            "browseId": "UC-alice"
                                          }
                                        }
                                      }
                                    }
                                  }
                                }
                              },
                              {
                                "listItemViewModel": {
                                  "title": {
                                    "content": "Alice Again"
                                  },
                                  "rendererContext": {
                                    "commandContext": {
                                      "onTap": {
                                        "innertubeCommand": {
                                          "browseEndpoint": {
                                            "browseId": "UC-alice"
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
      JSON

    result = Invidious::Videos::Parser.parse_related_video(related).not_nil!
    expect(result["ucid"].as_s).to eq("UC-alice")
    expect(result.has_key?("author_list")).to be_false
  end
end
