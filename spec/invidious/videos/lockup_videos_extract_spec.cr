require "../../parsers_helper.cr"

# Wraps a raw lockupViewModel the same way YouTube encapsulates it in a
# channel videos tab (richGridRenderer -> richItemRenderer -> content).
private def wrap_lockup(lockup : JSON::Any) : Hash(String, JSON::Any)
  wrapped = {
    "twoColumnBrowseResultsRenderer" => {
      "tabs" => [{
        "tabRenderer" => {
          "selected" => true,
          "content"  => {
            "richGridRenderer" => {
              "contents" => [{"richItemRenderer" => {"content" => {"lockupViewModel" => lockup}}}],
            },
          },
        },
      }],
    },
  }

  return JSON.parse(wrapped.to_json).as_h
end

Spectator.describe "extract_items" do
  # Real InnerTube data, captured from a channel videos tab (2026-08).
  # The collab video has an additional metadata row containing the channel
  # names, which pushes the views/published data into the second row.
  # See: https://github.com/iv-org/invidious/issues/5740
  COLLAB_VIDEO_LOCKUP = JSON.parse(%q({"contentType":"LOCKUP_CONTENT_TYPE_VIDEO","contentId":"kS-CGkiPetQ","contentImage":{"thumbnailViewModel":{"image":{"sources":[{"url":"https://i.ytimg.com/vi/kS-CGkiPetQ/hqdefault.jpg","width":360,"height":202}]},"overlays":[{"thumbnailBottomOverlayViewModel":{"badges":[{"thumbnailBadgeViewModel":{"text":"29:54"}}]}}]}},"metadata":{"lockupMetadataViewModel":{"title":{"content":"Google Maps is unreasonably fast. Let me explain"},"metadata":{"contentMetadataViewModel":{"metadataRows":[{"metadataParts":[{"text":{"content":"Veritasium and 2swap","styleRuns":[{"startIndex":0,"length":20},{"startIndex":10,"length":1,"styleRunExtensions":{"styleRunColorMapExtension":{"colorMap":[{"key":"USER_INTERFACE_THEME_DARK","value":4289374890},{"key":"USER_INTERFACE_THEME_LIGHT","value":4284506208}]}}},{"startIndex":20,"styleRunExtensions":{"styleRunColorMapExtension":{"colorMap":[{"key":"USER_INTERFACE_THEME_DARK","value":4289374890},{"key":"USER_INTERFACE_THEME_LIGHT","value":4284506208}]}}}],"attachmentRuns":[{"startIndex":10,"element":{"type":{"imageType":{"image":{"sources":[{"clientResource":{"imageName":"CHECK_CIRCLE_FILLED"},"width":14,"height":14}]}}},"properties":{"layoutProperties":{"height":{"value":14,"unit":"DIMENSION_UNIT_POINT"},"width":{"value":14,"unit":"DIMENSION_UNIT_POINT"},"margin":{"left":{"value":4,"unit":"DIMENSION_UNIT_POINT"}}}}},"alignment":"ALIGNMENT_VERTICAL_CENTER"},{"startIndex":20,"element":{"type":{"imageType":{"image":{"sources":[{"clientResource":{"imageName":"CHECK_CIRCLE_FILLED"},"width":14,"height":14}]}}},"properties":{"layoutProperties":{"height":{"value":14,"unit":"DIMENSION_UNIT_POINT"},"width":{"value":14,"unit":"DIMENSION_UNIT_POINT"},"margin":{"left":{"value":4,"unit":"DIMENSION_UNIT_POINT"}}}}},"alignment":"ALIGNMENT_VERTICAL_CENTER"}]}}]},{"metadataParts":[{"text":{"content":"7.9M views"}},{"text":{"content":"2 months ago"},"accessibilityLabel":"2 months ago"}]}]}}}}}))

  REGULAR_VIDEO_LOCKUP = JSON.parse(%q({"contentType":"LOCKUP_CONTENT_TYPE_VIDEO","contentId":"J1WoNuemKOg","contentImage":{"thumbnailViewModel":{"image":{"sources":[{"url":"https://i.ytimg.com/vi/J1WoNuemKOg/hqdefault.jpg","width":360,"height":202}]},"overlays":[{"thumbnailBottomOverlayViewModel":{"badges":[{"thumbnailBadgeViewModel":{"text":"22:45"}}]}}]}},"metadata":{"lockupMetadataViewModel":{"title":{"content":"Total Solar Eclipse from 92,000 Feet"},"metadata":{"contentMetadataViewModel":{"metadataRows":[{"metadataParts":[{"text":{"content":"1.6M views"}},{"text":{"content":"4 days ago"},"accessibilityLabel":"4 days ago"}]}]}}}}}))

  # Same collab video, but with channel names containing the words "views"
  # and "ago" to ensure they are not mistaken for actual video metadata.
  # (fixture derived from the one above, only the author names were changed)
  TRICKY_NAMES_LOCKUP = JSON.parse(%q({"contentType":"LOCKUP_CONTENT_TYPE_VIDEO","contentId":"kS-CGkiPetQ","contentImage":{"thumbnailViewModel":{"image":{"sources":[{"url":"https://i.ytimg.com/vi/kS-CGkiPetQ/hqdefault.jpg","width":360,"height":202}]},"overlays":[{"thumbnailBottomOverlayViewModel":{"badges":[{"thumbnailBadgeViewModel":{"text":"29:54"}}]}}]}},"metadata":{"lockupMetadataViewModel":{"title":{"content":"Google Maps is unreasonably fast. Let me explain"},"metadata":{"contentMetadataViewModel":{"metadataRows":[{"metadataParts":[{"text":{"content":"Daily Views Channel and Long Ago Podcast","styleRuns":[{"startIndex":0,"length":20},{"startIndex":10,"length":1,"styleRunExtensions":{"styleRunColorMapExtension":{"colorMap":[{"key":"USER_INTERFACE_THEME_DARK","value":4289374890},{"key":"USER_INTERFACE_THEME_LIGHT","value":4284506208}]}}},{"startIndex":20,"styleRunExtensions":{"styleRunColorMapExtension":{"colorMap":[{"key":"USER_INTERFACE_THEME_DARK","value":4289374890},{"key":"USER_INTERFACE_THEME_LIGHT","value":4284506208}]}}}],"attachmentRuns":[{"startIndex":10,"element":{"type":{"imageType":{"image":{"sources":[{"clientResource":{"imageName":"CHECK_CIRCLE_FILLED"},"width":14,"height":14}]}}},"properties":{"layoutProperties":{"height":{"value":14,"unit":"DIMENSION_UNIT_POINT"},"width":{"value":14,"unit":"DIMENSION_UNIT_POINT"},"margin":{"left":{"value":4,"unit":"DIMENSION_UNIT_POINT"}}}}},"alignment":"ALIGNMENT_VERTICAL_CENTER"},{"startIndex":20,"element":{"type":{"imageType":{"image":{"sources":[{"clientResource":{"imageName":"CHECK_CIRCLE_FILLED"},"width":14,"height":14}]}}},"properties":{"layoutProperties":{"height":{"value":14,"unit":"DIMENSION_UNIT_POINT"},"width":{"value":14,"unit":"DIMENSION_UNIT_POINT"},"margin":{"left":{"value":4,"unit":"DIMENSION_UNIT_POINT"}}}}},"alignment":"ALIGNMENT_VERTICAL_CENTER"}]}}]},{"metadataParts":[{"text":{"content":"7.9M views"}},{"text":{"content":"2 months ago"},"accessibilityLabel":"2 months ago"}]}]}}}}}))

  it "parses a regular channel video (views and published in first row)" do
    items, _continuation = extract_items(wrap_lockup(REGULAR_VIDEO_LOCKUP), "Veritasium", "UCHnyfMqiRRG1u-2MsSQLbXA")
    videos = items.select(SearchVideo)

    expect(videos.size).to eq(1)

    video = videos[0]
    expect(video.id).to eq("J1WoNuemKOg")
    expect(video.title).to eq("Total Solar Eclipse from 92,000 Feet")
    expect(video.views).to eq(1_600_000)
    expect((video.published - decode_date("4 days ago")).abs).to be < 1.second
    expect(video.length_seconds).to eq(22*60 + 45)
  end

  it "parses a collaboration channel video (extra metadata row with authors)" do
    items, _continuation = extract_items(wrap_lockup(COLLAB_VIDEO_LOCKUP), "Veritasium", "UCHnyfMqiRRG1u-2MsSQLbXA")
    videos = items.select(SearchVideo)

    expect(videos.size).to eq(1)

    video = videos[0]
    expect(video.id).to eq("kS-CGkiPetQ")
    expect(video.title).to eq("Google Maps is unreasonably fast. Let me explain")

    # Before the fix, views were 0 and published fell back to Time.local,
    # because only metadataRows[0] (which contains the authors) was looked at.
    expect(video.views).to eq(7_900_000)
    expect((video.published - decode_date("2 months ago")).abs).to be < 1.second
    expect(video.length_seconds).to eq(29*60 + 54)
  end

  it "parses a collab video whose channel names contain views/ago" do
    initial_data = JSON.parse({
      "twoColumnBrowseResultsRenderer" => {
        "tabs" => [{
          "tabRenderer" => {
            "selected" => true,
            "content"  => {
              "richGridRenderer" => {
                "contents" => [{"richItemRenderer" => {"content" => {"lockupViewModel" => TRICKY_NAMES_LOCKUP}}}],
              },
            },
          },
        }],
      },
    }.to_json).as_h

    items, _continuation = extract_items(initial_data, "Veritasium", "UCHnyfMqiRRG1u-2MsSQLbXA")
    videos = items.select(SearchVideo)

    expect(videos.size).to eq(1)

    video = videos[0]
    expect(video.id).to eq("kS-CGkiPetQ")
    expect(video.views).to eq(7_900_000)
    expect((video.published - decode_date("2 months ago")).abs).to be < 1.second
  end
end
