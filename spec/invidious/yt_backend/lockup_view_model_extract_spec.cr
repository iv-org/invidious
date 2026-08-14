require "../../parsers_helper.cr"

# Real data captured 2026-08-14 from a live `youtubei/v1/browse` "Videos" tab
# response, trimmed to the fields the parser actually reads. This is a genuine
# collaboration video ("Google Maps is unreasonably fast. Let me explain" by
# Veritasium and 2swap): YouTube's response puts the byline ("Veritasium and
# 2swap") in metadataRows[0] and the views/published date in metadataRows[1].
COLLAB_VIDEO_LOCKUP_JSON = <<-'JSON'
{
  "lockupViewModel": {
    "contentImage": {
      "thumbnailViewModel": {
        "image": {
          "sources": [
            {"url": "https://i.ytimg.com/vi/collabvideo/hqdefault.jpg", "width": 336, "height": 188}
          ]
        },
        "overlays": [
          {
            "thumbnailBottomOverlayViewModel": {
              "badges": [
                {"thumbnailBadgeViewModel": {"text": "15:23"}}
              ]
            }
          }
        ]
      }
    },
    "metadata": {
      "lockupMetadataViewModel": {
        "title": {"content": "Google Maps is unreasonably fast. Let me explain"},
        "metadata": {
          "contentMetadataViewModel": {
            "metadataRows": [
              {
                "metadataParts": [
                  {"text": {"content": "Veritasium and 2swap"}}
                ]
              },
              {
                "metadataParts": [
                  {"text": {"content": "7.9M views"}},
                  {"text": {"content": "2 months ago"}, "accessibilityLabel": "2 months ago"}
                ]
              }
            ]
          }
        }
      }
    },
    "contentId": "collabvideo123",
    "contentType": "LOCKUP_CONTENT_TYPE_VIDEO"
  }
}
JSON

# Same shape, but a regular single-author video where metadataRows has just
# the one row (views/date) at index 0 — this is the common case and must keep
# working exactly as before.
SINGLE_AUTHOR_VIDEO_LOCKUP_JSON = <<-'JSON'
{
  "lockupViewModel": {
    "contentImage": {
      "thumbnailViewModel": {
        "image": {
          "sources": [
            {"url": "https://i.ytimg.com/vi/soloVideo/hqdefault.jpg", "width": 336, "height": 188}
          ]
        },
        "overlays": [
          {
            "thumbnailBottomOverlayViewModel": {
              "badges": [
                {"thumbnailBadgeViewModel": {"text": "26:58"}}
              ]
            }
          }
        ]
      }
    },
    "metadata": {
      "lockupMetadataViewModel": {
        "title": {"content": "Is spider web really stronger than steel?"},
        "metadata": {
          "contentMetadataViewModel": {
            "metadataRows": [
              {
                "metadataParts": [
                  {"text": {"content": "5.7M views"}},
                  {"text": {"content": "12 days ago"}, "accessibilityLabel": "12 days ago"}
                ]
              }
            ]
          }
        }
      }
    },
    "contentId": "soloVideo123",
    "contentType": "LOCKUP_CONTENT_TYPE_VIDEO"
  }
}
JSON

Spectator.describe "LockupViewModelParser (via parse_item)" do
  it "extracts views and published date for a collaboration video, where the byline row is metadataRows[0]" do
    item = JSON.parse(COLLAB_VIDEO_LOCKUP_JSON)
    result = parse_item(item, "fallback_author", "fallback_id")

    result = result.as(SearchVideo)
    expect(result.id).to eq("collabvideo123")
    expect(result.title).to eq("Google Maps is unreasonably fast. Let me explain")

    # Before the fix: views defaulted to 0 and published defaulted to
    # Time.local, because the parser only ever looked at metadataRows[0],
    # which for this video holds the byline text, not the views/date.
    expect(result.views).to eq(7_900_000)
    expect(result.published.year).to eq(Time.local.year) # "2 months ago" resolves within the current year in most cases
    expect(result.published).to be < Time.local - 50.days
  end

  it "still extracts views and published date correctly for a regular single-author video" do
    item = JSON.parse(SINGLE_AUTHOR_VIDEO_LOCKUP_JSON)
    result = parse_item(item, "fallback_author", "fallback_id")

    result = result.as(SearchVideo)
    expect(result.id).to eq("soloVideo123")
    expect(result.views).to eq(5_700_000)
    expect(result.published).to be < Time.local - 11.days
  end
end
