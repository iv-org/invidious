require "../../parsers_helper.cr"

Spectator.describe "parse_description" do
  it "parses a description without any run" do
    desc = JSON.parse(%({"content": "Hello <world> & \\"friends\\""}))

    expect(parse_description(desc, "")).to eq(
      "Hello &lt;world&gt; &amp; &quot;friends&quot;"
    )
  end

  it "parses a description with a link (commandRuns)" do
    desc = JSON.parse(<<-JSON)
      {
        "content": "Watch this",
        "commandRuns": [
          {
            "startIndex": 0,
            "length": 5,
            "onTap": {
              "innertubeCommand": {
                "watchEndpoint": { "videoId": "dQw4w9WgXcQ" }
              }
            }
          }
        ]
      }
      JSON

    expect(parse_description(desc, "someOtherId")).to eq(
      %(<a href="/watch?v=dQw4w9WgXcQ">Watch</a> this)
    )
  end

  # Standard emojis are sent as an attachment, but the content string already
  # contains the real unicode character, so the text must be left untouched.
  # Captured from https://www.youtube.com/watch?v=Gy3bmuzmWMM
  it "keeps standard emojis as unicode" do
    desc = JSON.parse(<<-JSON)
      {
        "content": "everyone deserves to grow❤️",
        "attachmentRuns": [
          {
            "startIndex": 25,
            "length": 1,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [
                      {
                        "url": "https://www.youtube.com/s/gaming/emoji/7ff574f2/emoji_u2764.png",
                        "width": 16,
                        "height": 16
                      }
                    ]
                  }
                }
              },
              "properties": {
                "accessibilityProperties": { "label": "❤" }
              }
            }
          }
        ]
      }
      JSON

    expect(parse_description(desc, "")).to eq("everyone deserves to grow❤️")
  end

  # Youtube inserts social media icons in descriptions with a length of 0,
  # meaning no text is covered by the attachment.
  # Captured from https://www.youtube.com/watch?v=Gy3bmuzmWMM
  it "does not consume text for a zero length attachment" do
    desc = JSON.parse(<<-JSON)
      {
        "content": "Follow me on twitter",
        "attachmentRuns": [
          {
            "startIndex": 14,
            "length": 0,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [
                      { "url": "https://www.gstatic.com/youtube/img/watch/social_media/twitter_1x_v2.png" }
                    ]
                  }
                }
              }
            }
          }
        ]
      }
      JSON

    expect(parse_description(desc, "")).to eq("Follow me on twitter")
  end

  # Custom channel emojis have no unicode equivalent and are hosted on ggpht,
  # so they must be rendered as a proxied image.
  it "renders custom channel emojis as an image" do
    desc = JSON.parse(<<-JSON)
      {
        "content": "nice video :_ToonThumbsUp:",
        "attachmentRuns": [
          {
            "startIndex": 11,
            "length": 15,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [
                      {
                        "url": "https://yt3.ggpht.com/abcdef=w24-h24-c-k-nd",
                        "width": 24,
                        "height": 24
                      }
                    ]
                  }
                }
              },
              "properties": {
                "layoutProperties": {
                  "width": { "value": 24 },
                  "height": { "value": 24 }
                },
                "accessibilityProperties": { "label": "ToonThumbsUp" }
              }
            }
          }
        ]
      }
      JSON

    expect(parse_description(desc, "")).to eq(
      %(nice video <img alt="ToonThumbsUp" src="/ggpht/abcdef=w24-h24-c-k-nd" ) +
      %(title="ToonThumbsUp" width="24" height="24" class="channel-emoji" />)
    )
  end

  # Both kinds of run index into the same string and share a single iterator,
  # so they have to be walked in order of appearance.
  it "parses a description mixing a link and a custom emoji" do
    desc = JSON.parse(<<-JSON)
      {
        "content": ":_Hi: watch",
        "commandRuns": [
          {
            "startIndex": 6,
            "length": 5,
            "onTap": {
              "innertubeCommand": {
                "watchEndpoint": { "videoId": "dQw4w9WgXcQ" }
              }
            }
          }
        ],
        "attachmentRuns": [
          {
            "startIndex": 0,
            "length": 5,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [
                      { "url": "https://yt3.ggpht.com/xyz=w24-h24-c-k-nd", "width": 24, "height": 24 }
                    ]
                  }
                }
              },
              "properties": {
                "accessibilityProperties": { "label": "Hi" }
              }
            }
          }
        ]
      }
      JSON

    expect(parse_description(desc, "someOtherId")).to eq(
      %(<img alt="Hi" src="/ggpht/xyz=w24-h24-c-k-nd" title="Hi" width="24" height="24" class="channel-emoji" />) +
      %( <a href="/watch?v=dQw4w9WgXcQ">watch</a>)
    )
  end

  # Real capture of the comment linked in #5888, whose emojis are hosted on
  # lh3.googleusercontent.com rather than ggpht:
  # https://www.youtube.com/watch?v=Gy3bmuzmWMM&lc=UgxVdYO3R6wrr9sLhT54AaABAg
  it "renders the emojis of the comment reported in #5888" do
    desc = JSON.parse(<<-JSON)
      {
        "content": ":face-red-heart-shape:",
        "attachmentRuns": [
          {
            "startIndex": 0,
            "length": 22,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [
                      {
                        "url": "https://lh3.googleusercontent.com/I0Mem9dU=s16-w24-h24-c-k-nd",
                        "width": 16,
                        "height": 16
                      }
                    ]
                  }
                }
              },
              "properties": {
                "layoutProperties": {
                  "height": { "value": 16 },
                  "width": { "value": 16 }
                },
                "accessibilityProperties": { "label": "face-red-heart-shape" }
              }
            }
          }
        ]
      }
      JSON

    expect(parse_description(desc, "")).to eq(
      %(<img alt="face-red-heart-shape" src="/ggpht/I0Mem9dU=s16-w24-h24-c-k-nd" ) +
      %(title="face-red-heart-shape" width="16" height="16" class="channel-emoji" />)
    )
  end

  it "does not treat a gstatic image as a custom emoji" do
    desc = JSON.parse(<<-JSON)
      {
        "content": "hi",
        "attachmentRuns": [
          {
            "startIndex": 0,
            "length": 2,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [
                      { "url": "https://www.gstatic.com/youtube/img/watch/x.png", "width": 16, "height": 16 }
                    ]
                  }
                }
              },
              "properties": {
                "accessibilityProperties": { "label": "x" }
              }
            }
          }
        ]
      }
      JSON

    expect(parse_description(desc, "")).to eq("hi")
  end

  # copy_string escapes the text as it copies it, so the fallback used when
  # youtube sends no label must not be escaped a second time.
  it "does not escape the fallback label twice" do
    desc = JSON.parse(<<-JSON)
      {
        "content": "a&b",
        "attachmentRuns": [
          {
            "startIndex": 0,
            "length": 3,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [
                      { "url": "https://yt3.ggpht.com/x=w24-h24", "width": 24, "height": 24 }
                    ]
                  }
                }
              }
            }
          }
        ]
      }
      JSON

    expect(parse_description(desc, "")).to eq(
      %(<img alt="a&amp;b" src="/ggpht/x=w24-h24" title="a&amp;b" ) +
      %(width="24" height="24" class="channel-emoji" />)
    )
  end

  # URI#request_target returns the path untouched, quotes included, so it has
  # to be escaped before being placed inside the src attribute.
  it "escapes a quote in the image url" do
    desc = JSON.parse(<<-JSON)
      {
        "content": "hi",
        "attachmentRuns": [
          {
            "startIndex": 0,
            "length": 2,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [
                      { "url": "https://yt3.ggpht.com/x\\"onerror=alert(1) a=\\"", "width": 24, "height": 24 }
                    ]
                  }
                }
              },
              "properties": {
                "accessibilityProperties": { "label": "e" }
              }
            }
          }
        ]
      }
      JSON

    expect(parse_description(desc, "")).to eq(
      %(<img alt="e" src="/ggpht/x&quot;onerror=alert(1) a=&quot;" title="e" ) +
      %(width="24" height="24" class="channel-emoji" />)
    )
  end

  # Matching the bare domain suffix would let a lookalike host through.
  it "rejects a lookalike emoji host" do
    desc = JSON.parse(<<-JSON)
      {
        "content": "hi",
        "attachmentRuns": [
          {
            "startIndex": 0,
            "length": 2,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [
                      { "url": "https://evilgoogleusercontent.com/x=w24-h24", "width": 24, "height": 24 }
                    ]
                  }
                }
              },
              "properties": {
                "accessibilityProperties": { "label": "e" }
              }
            }
          }
        ]
      }
      JSON

    expect(parse_description(desc, "")).to eq("hi")
  end

  # A zero length attachment consumes no text, so a command starting at the
  # same index must not advance the cursor past it and drop the image.
  it "keeps a zero-length attachment sharing an index with a command" do
    desc = JSON.parse(<<-JSON)
      {
        "content": "watch",
        "commandRuns": [
          {
            "startIndex": 0,
            "length": 5,
            "onTap": {
              "innertubeCommand": {
                "watchEndpoint": { "videoId": "dQw4w9WgXcQ" }
              }
            }
          }
        ],
        "attachmentRuns": [
          {
            "startIndex": 0,
            "length": 0,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [
                      { "url": "https://yt3.ggpht.com/z=w24-h24", "width": 24, "height": 24 }
                    ]
                  }
                }
              },
              "properties": {
                "accessibilityProperties": { "label": "e" }
              }
            }
          }
        ]
      }
      JSON

    expect(parse_description(desc, "someOtherId")).to eq(
      %(<img alt="e" src="/ggpht/z=w24-h24" title="e" width="24" height="24" class="channel-emoji" />) +
      %(<a href="/watch?v=dQw4w9WgXcQ">watch</a>)
    )
  end

  # Youtube counts indexes in UTF-16 code units, so a single SMP codepoint
  # placed before a run shifts every following index by two.
  it "handles offsets after an SMP codepoint" do
    desc = JSON.parse(<<-JSON)
      {
        "content": "\u{1F600} :_Test:",
        "attachmentRuns": [
          {
            "startIndex": 3,
            "length": 7,
            "element": {
              "type": {
                "imageType": {
                  "image": {
                    "sources": [
                      { "url": "https://yt3.ggpht.com/test=w24-h24-c-k-nd", "width": 24, "height": 24 }
                    ]
                  }
                }
              },
              "properties": {
                "accessibilityProperties": { "label": "Test" }
              }
            }
          }
        ]
      }
      JSON

    expect(parse_description(desc, "")).to eq(
      %(\u{1F600} <img alt="Test" src="/ggpht/test=w24-h24-c-k-nd" title="Test" width="24" height="24" class="channel-emoji" />)
    )
  end
end
