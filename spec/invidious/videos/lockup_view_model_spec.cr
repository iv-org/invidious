require "../../parsers_helper.cr"

Spectator.describe "LockupViewModelParser" do
  it "parses collaboration video with multiple metadataRows (fixes #5740)" do
    raw_json = <<-JSON
    {
      "lockupViewModel": {
        "contentType": "LOCKUP_CONTENT_TYPE_VIDEO",
        "contentId": "dQw4w9WgXcQ",
        "contentImage": {
          "thumbnailViewModel": {
            "image": {
              "sources": [
                {
                  "url": "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
                }
              ]
            },
            "overlays": [
              {
                "thumbnailBottomOverlayViewModel": {
                  "badges": [
                    {
                      "thumbnailBadgeViewModel": {
                        "text": "3:33"
                      }
                    }
                  ]
                }
              }
            ]
          }
        },
        "metadata": {
          "lockupMetadataViewModel": {
            "title": {
              "content": "Collaboration Video Title"
            },
            "metadata": {
              "contentMetadataViewModel": {
                "metadataRows": [
                  {
                    "metadataParts": [
                      {
                        "text": {
                          "content": "Veritasium and 2swap"
                        }
                      }
                    ]
                  },
                  {
                    "metadataParts": [
                      {
                        "text": {
                          "content": "8.8M views"
                        }
                      },
                      {
                        "text": {
                          "content": "5 months ago"
                        }
                      }
                    ]
                  }
                ]
              }
            }
          }
        }
      }
    }
    JSON

    item = JSON.parse(raw_json)
    parsed = parse_item(item, "Veritasium", "UCHnyfMqiRRG1u-2MsSQLbXA")

    expect(parsed).to be_a(SearchVideo)
    video = parsed.as(SearchVideo)

    expect(video.id).to eq("dQw4w9WgXcQ")
    expect(video.title).to eq("Collaboration Video Title")
    expect(video.author).to eq("Veritasium")
    expect(video.ucid).to eq("UCHnyfMqiRRG1u-2MsSQLbXA")
    expect(video.views).to eq(8_800_000_i64)
    expect(video.length_seconds).to eq(213)
    expect(video.published).to be <= (Time.local - 4.months)
  end

  it "parses regular video with single metadataRow" do
    raw_json = <<-JSON
    {
      "lockupViewModel": {
        "contentType": "LOCKUP_CONTENT_TYPE_VIDEO",
        "contentId": "single_author_id",
        "contentImage": {
          "thumbnailViewModel": {
            "image": {
              "sources": [
                {
                  "url": "https://i.ytimg.com/vi/single/hqdefault.jpg"
                }
              ]
            },
            "overlays": [
              {
                "thumbnailBottomOverlayViewModel": {
                  "badges": [
                    {
                      "thumbnailBadgeViewModel": {
                        "text": "10:00"
                      }
                    }
                  ]
                }
              }
            ]
          }
        },
        "metadata": {
          "lockupMetadataViewModel": {
            "title": {
              "content": "Single Author Title"
            },
            "metadata": {
              "contentMetadataViewModel": {
                "metadataRows": [
                  {
                    "metadataParts": [
                      {
                        "text": {
                          "content": "1.2M views"
                        }
                      },
                      {
                        "text": {
                          "content": "2 days ago"
                        }
                      }
                    ]
                  }
                ]
              }
            }
          }
        }
      }
    }
    JSON

    item = JSON.parse(raw_json)
    parsed = parse_item(item, "AuthorName", "UCauthor123")

    expect(parsed).to be_a(SearchVideo)
    video = parsed.as(SearchVideo)

    expect(video.id).to eq("single_author_id")
    expect(video.title).to eq("Single Author Title")
    expect(video.views).to eq(1_200_000_i64)
    expect(video.length_seconds).to eq(600)
    expect(video.published).to be <= (Time.local - 1.days)
  end
end
