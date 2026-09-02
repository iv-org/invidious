require "../../parsers_helper.cr"

LEGACY_SINGLE_AUTHOR_RELATED_VIDEO = <<-JSON
  {
    "videoId": "XuoqKYxDHVc",
    "title": {"simpleText": "Single-author recommendation"},
    "lengthInSeconds": 5107,
    "shortViewCountText": {"simpleText": "3.1M views"},
    "publishedTimeText": {"simpleText": "4 days ago"},
    "shortBylineText": {
      "runs": [{
        "text": "The Economist",
        "navigationEndpoint": {
          "browseEndpoint": {"browseId": "UC0p5jTq6Xx_DosDFxVXnWaQ"}
        }
      }]
    }
  }
  JSON

SINGLE_AUTHOR_LOCKUP_RELATED_VIDEO = <<-JSON
  {
    "contentId": "_g4l7YkDQwA",
    "contentType": "LOCKUP_CONTENT_TYPE_VIDEO",
    "contentImage": {
      "thumbnailViewModel": {
        "decoratedAvatarViewModel": {
          "rendererContext": {
            "commandContext": {
              "onTap": {
                "innertubeCommand": {
                  "browseEndpoint": {"browseId": "UCGq-a57w-aPwyi3pW7XLiHw"}
                }
              }
            }
          }
        },
        "overlays": [{
          "thumbnailBottomOverlayViewModel": {
            "badges": [{"thumbnailBadgeViewModel": {"text": "1:42:19"}}]
          }
        }]
      }
    },
    "metadata": {
      "lockupMetadataViewModel": {
        "title": {"content": "Single-author lockup recommendation"},
        "metadata": {
          "contentMetadataViewModel": {
            "metadataRows": [
              {
                "metadataParts": [{
                  "text": {
                    "content": "The Diary Of A CEO",
                    "attachmentRuns": [{
                      "element": {
                        "type": {
                          "imageType": {
                            "image": {
                              "sources": [{
                                "clientResource": {"imageName": "CHECK_CIRCLE_FILLED"}
                              }]
                            }
                          }
                        }
                      }
                    }]
                  }
                }]
              },
              {
                "metadataParts": [
                  {
                    "text": {"content": "4.5M"}
                  },
                  {
                    "text": {"content": "3mo ago"},
                    "accessibilityLabel": "3 months ago"
                  }
                ]
              }
            ]
          }
        }
      }
    }
  }
  JSON

MULTIPLE_AUTHORS_LOCKUP_RELATED_VIDEO = <<-JSON
  {
    "contentId": "4klivapz4Gw",
    "contentType": "LOCKUP_CONTENT_TYPE_VIDEO",
    "contentImage": {
      "thumbnailViewModel": {
        "overlays": [{
          "thumbnailBottomOverlayViewModel": {
            "badges": [{"thumbnailBadgeViewModel": {"text": "3:06:19"}}]
          }
        }]
      }
    },
    "metadata": {
      "lockupMetadataViewModel": {
        "title": {"content": "Collaborative lockup recommendation"},
        "image": {
          "avatarStackViewModel": {
            "rendererContext": {
              "commandContext": {
                "onTap": {
                  "innertubeCommand": {
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
                                        "content": "Chris Williamson",
                                        "attachmentRuns": [{
                                          "element": {
                                            "type": {
                                              "imageType": {
                                                "image": {
                                                  "sources": [{
                                                    "clientResource": {"imageName": "CHECK_CIRCLE_FILLED"}
                                                  }]
                                                }
                                              }
                                            }
                                          }
                                        }]
                                      },
                                      "rendererContext": {
                                        "commandContext": {
                                          "onTap": {
                                            "innertubeCommand": {
                                              "browseEndpoint": {"browseId": "UCIaH-gZIVC432YRjNVvnyCA"}
                                            }
                                          }
                                        }
                                      }
                                    }
                                  },
                                  {
                                    "listItemViewModel": {
                                      "title": {"content": "Predictive History"},
                                      "rendererContext": {
                                        "commandContext": {
                                          "onTap": {
                                            "innertubeCommand": {
                                              "browseEndpoint": {"browseId": "UC11aHtNnc5bEPLI4jf6mnYg"}
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
                                              "browseEndpoint": {"browseId": "UC-without-name"}
                                            }
                                          }
                                        }
                                      }
                                    }
                                  },
                                  {
                                    "listItemViewModel": {
                                      "title": {"content": "Unlinked collaborator"}
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
              }
            }
          }
        },
        "metadata": {
          "contentMetadataViewModel": {
            "metadataRows": [
              {
                "metadataParts": [{
                  "text": {"content": "Chris Williamson and Predictive History"}
                }]
              },
              {
                "metadataParts": [
                  {
                    "text": {"content": "1.2M"}
                  },
                  {
                    "text": {"content": "2mo ago"},
                    "accessibilityLabel": "2 months ago"
                  }
                ]
              }
            ]
          }
        }
      }
    }
  }
  JSON

Spectator.describe Invidious::Videos::Parser do
  describe ".parse_related_video" do
    it "preserves support for legacy single-author renderers" do
      related = Invidious::Videos::Parser.parse_related_video(
        JSON.parse(LEGACY_SINGLE_AUTHOR_RELATED_VIDEO)
      ).not_nil!

      expect(related["author"].as_s).to eq("The Economist")
      expect(related["ucid"].as_s).to eq("UC0p5jTq6Xx_DosDFxVXnWaQ")
      expect(related["authors"]?).to be_nil
    end

    it "parses a single-author lockup renderer" do
      related = Invidious::Videos::Parser.parse_related_video(
        JSON.parse(SINGLE_AUTHOR_LOCKUP_RELATED_VIDEO)
      ).not_nil!

      expect(related["id"].as_s).to eq("_g4l7YkDQwA")
      expect(related["title"].as_s).to eq("Single-author lockup recommendation")
      expect(related["author"].as_s).to eq("The Diary Of A CEO")
      expect(related["ucid"].as_s).to eq("UCGq-a57w-aPwyi3pW7XLiHw")
      expect(related["author_verified"].as_s).to eq("true")
      expect(related["length_seconds"].as_s).to eq("6139")
      expect(related["short_view_count"].as_s).to eq("4.5M")
      expect(related["published"].as_s).not_to be_empty
      expect(related["authors"]?).to be_nil
    end

    it "extracts every named collaborator from a lockup avatar stack" do
      related = Invidious::Videos::Parser.parse_related_video(
        JSON.parse(MULTIPLE_AUTHORS_LOCKUP_RELATED_VIDEO)
      ).not_nil!
      authors = related["authors"].as_a

      expect(related["id"].as_s).to eq("4klivapz4Gw")
      expect(related["author"].as_s).to eq("Chris Williamson and Predictive History")
      expect(related["ucid"].as_s).to be_empty
      expect(related["length_seconds"].as_s).to eq("11179")
      expect(related["short_view_count"].as_s).to eq("1.2M")
      expect(authors.size).to eq(3)

      expect(authors[0]["author"].as_s).to eq("Chris Williamson")
      expect(authors[0]["ucid"].as_s).to eq("UCIaH-gZIVC432YRjNVvnyCA")
      expect(authors[0]["verified"].as_bool).to be_true

      expect(authors[1]["author"].as_s).to eq("Predictive History")
      expect(authors[1]["ucid"].as_s).to eq("UC11aHtNnc5bEPLI4jf6mnYg")
      expect(authors[1]["verified"].as_bool).to be_false

      expect(authors[2]["author"].as_s).to eq("Unlinked collaborator")
      expect(authors[2]["ucid"].as_s).to be_empty
    end

    it "ignores non-video lockups" do
      related = JSON.parse(%({"contentId":"playlist","contentType":"LOCKUP_CONTENT_TYPE_PLAYLIST"}))
      expect(Invidious::Videos::Parser.parse_related_video(related)).to be_nil
    end

    it "extracts lockups wrapped in an item section" do
      lockup = JSON.parse(MULTIPLE_AUTHORS_LOCKUP_RELATED_VIDEO)
      results = JSON.parse({
        "itemSectionRenderer" => {
          "contents" => [
            {"lockupViewModel" => lockup},
            {"continuationItemRenderer" => {"trigger" => "CONTINUATION_TRIGGER_ON_ITEM_SHOWN"}},
          ],
        },
      }.to_json)

      related = Invidious::Videos::Parser.parse_related_videos(JSON::Any.new([results]))

      expect(related.size).to eq(1)
      expect(related[0]["id"].as_s).to eq("4klivapz4Gw")
      expect(related[0]["authors"].as_a.map(&.["author"].as_s)).to eq([
        "Chris Williamson",
        "Predictive History",
        "Unlinked collaborator",
      ])
    end

    it "does not classify author-like metadata as views or publication dates" do
      lockup = JSON.parse(MULTIPLE_AUTHORS_LOCKUP_RELATED_VIDEO.sub(
        "Chris Williamson and Predictive History",
        "Daily Views Channel and Long Ago Podcast"
      ))

      related = Invidious::Videos::Parser.parse_related_video(lockup).not_nil!

      expect(related["author"].as_s).to eq("Daily Views Channel and Long Ago Podcast")
      expect(related["short_view_count"].as_s).to eq("1.2M")
      expect(related["published"].as_s).not_to be_empty
    end
  end
end

Spectator.describe Video do
  describe "#related_videos" do
    it "exposes structured collaborators while retaining legacy fields" do
      parsed = Invidious::Videos::Parser.parse_related_video(
        JSON.parse(MULTIPLE_AUTHORS_LOCKUP_RELATED_VIDEO)
      ).not_nil!
      video = Video.new({
        id:   "IZZVijQ0gkA",
        info: {
          "relatedVideos" => JSON::Any.new([JSON::Any.new(parsed)]),
        },
        updated: Time.utc,
      })

      related = video.related_videos.first

      expect(related["id"].as_s).to eq("4klivapz4Gw")
      expect(related["author"].as_s).to eq("Chris Williamson and Predictive History")
      expect(related["ucid"].as_s).to be_empty
      expect(related["length_seconds"].as_s.to_i).to eq(11179)

      authors = related["authors"].as_a
      expect(authors.map(&.["author"].as_s)).to eq([
        "Chris Williamson",
        "Predictive History",
        "Unlinked collaborator",
      ])
      expect(authors.map(&.["ucid"].as_s)).to eq([
        "UCIaH-gZIVC432YRjNVvnyCA",
        "UC11aHtNnc5bEPLI4jf6mnYg",
        "",
      ])
    end
  end
end
