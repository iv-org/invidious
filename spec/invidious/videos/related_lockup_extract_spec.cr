require "../../parsers_helper.cr"

# Wraps raw lockupViewModel items the same way YouTube encapsulates them in
# the watch page's related videos section (secondaryResults -> results ->
# itemSectionRenderer -> contents).
private def wrap_related_lockup(lockups : Array(JSON::Any)) : Hash(String, JSON::Any)
  contents = lockups.map { |lockup| {"lockupViewModel" => lockup} }

  wrapped = {
    "secondaryResults": {
      "secondaryResults": {
        "results": [{
          "itemSectionRenderer": {
            "contents": contents,
          },
        }],
      },
    },
  }

  return JSON.parse(wrapped.to_json).as_h
end

Spectator.describe "parse_related_videos" do
  # Real InnerTube data, captured from a watch page's related videos
  # section (2026-08).
  # See: https://github.com/iv-org/invidious/issues/5722
  COLLAB_RELATED_LOCKUP = JSON.parse(%q({"contentType":"LOCKUP_CONTENT_TYPE_VIDEO","contentId":"ywd-Ve8a8Tc","contentImage":{"thumbnailViewModel":{"image":{"sources":[{"url":"https://i.ytimg.com/vi/ywd-Ve8a8Tc/hqdefault.jpg","width":360,"height":202}]},"overlays":[{"thumbnailBottomOverlayViewModel":{"badges":[{"thumbnailBadgeViewModel":{"text":"2:31:01"}}]}}]}},"metadata":{"lockupMetadataViewModel":{"title":{"content":"World Order Is a Lie: The Next 50 Years Will Change Everything"},"image":{"avatarStackViewModel":{"rendererContext":{"commandContext":{"onTap":{"innertubeCommand":{"showDialogCommand":{"panelLoadingStrategy":{"inlineContent":{"dialogViewModel":{"customContent":{"listViewModel":{"listItems":[{"listItemViewModel":{"title":{"content":"Raj Shamani"},"rendererContext":{"commandContext":{"onTap":{"innertubeCommand":{"browseEndpoint":{"browseId":"UCzwCEE_PchiBULMnAJqhGVg"}}}}}}},{"listItemViewModel":{"title":{"content":"Predictive History"},"rendererContext":{"commandContext":{"onTap":{"innertubeCommand":{"browseEndpoint":{"browseId":"UC11aHtNnc5bEPLI4jf6mnYg"}}}}}}}]}}}}}}}}}}}},"metadata":{"contentMetadataViewModel":{"metadataRows":[{"metadataParts":[{"text":{"content":"Raj Shamani and Predictive History","attachmentRuns":[{"element":{"type":{"imageType":{"image":{"sources":[{"clientResource":{"imageName":"CHECK_CIRCLE_FILLED"},"width":14,"height":14}]}}}}}]}}]},{"metadataParts":[{"text":{"content":"2M"}},{"text":{"content":"10d ago"}}]}]}}}}}))

  SINGLE_AUTHOR_RELATED_LOCKUP = JSON.parse(%q({"contentType":"LOCKUP_CONTENT_TYPE_VIDEO","contentId":"XuoqKYxDHVc","contentImage":{"thumbnailViewModel":{"decoratedAvatarViewModel":{"avatar":{"avatarViewModel":{"size":"AVATAR_SIZE_TYPE_M","image":{"sources":[{"url":"https://yt3.ggpht.com/ytc/example","width":88,"height":88}]}}},"rendererContext":{"commandContext":{"onTap":{"innertubeCommand":{"browseEndpoint":{"browseId":"UC0p5jTq6Xx_DosDFxVXnWaQ"}}}}}},"image":{"sources":[{"url":"https://i.ytimg.com/vi/XuoqKYxDHVc/hqdefault.jpg","width":360,"height":202}]},"overlays":[{"thumbnailBottomOverlayViewModel":{"badges":[{"thumbnailBadgeViewModel":{"text":"12:34"}}]}}]}},"metadata":{"lockupMetadataViewModel":{"title":{"content":"Why Russia Is Winning The Energy War"},"metadata":{"contentMetadataViewModel":{"metadataRows":[{"metadataParts":[{"text":{"content":"The Economist"}}]},{"metadataParts":[{"text":{"content":"1.2K views"}},{"text":{"content":"3w ago"}}]}]}}}}}))

  LEGACY_CVR_ITEM = JSON.parse(%q({"videoId":"aqz-KE-bpKQ","title":{"simpleText":"Big Buck Bunny"},"lengthText":{"simpleText":"9:56"},"shortBylineText":{"runs":[{"text":"Blender","navigationEndpoint":{"browseEndpoint":{"browseId":"UCSMOQeBJ2RAnuFungnYDxuA"}}}]},"ownerText":{"runs":[{"text":"Blender"}]},"shortViewCountText":{"simpleText":"10M views"},"publishedTimeText":{"simpleText":"15 years ago"}}))

  it "parses a collaboration related video with multiple channel links" do
    results = wrap_related_lockup([COLLAB_RELATED_LOCKUP]).dig?("secondaryResults", "secondaryResults", "results")

    related = Invidious::Videos::Parser.parse_related_videos(results)

    expect(related.size).to eq(1)

    video = related[0].as_h
    expect(video["id"].as_s).to eq("ywd-Ve8a8Tc")
    expect(video["ucid"].as_s).to eq("UCzwCEE_PchiBULMnAJqhGVg")
    expect(video["author"].as_s).to eq("Raj Shamani and Predictive History")
    expect(video["author_verified"].as_s).to eq("true")
    expect(video["length_seconds"].as_s).to eq((2*3600 + 31*60 + 1).to_s)
    expect(video["short_view_count"].as_s).to eq("2M")
    expect(Time.parse_rfc3339(video["published"].as_s)).to be_close(Time.local - 10.days, 1.days)
  end

  it "parses a single-author related video (channel link on avatar)" do
    results = wrap_related_lockup([SINGLE_AUTHOR_RELATED_LOCKUP]).dig?("secondaryResults", "secondaryResults", "results")

    related = Invidious::Videos::Parser.parse_related_videos(results)

    expect(related.size).to eq(1)

    video = related[0].as_h
    expect(video["id"].as_s).to eq("XuoqKYxDHVc")
    expect(video["ucid"].as_s).to eq("UC0p5jTq6Xx_DosDFxVXnWaQ")
    expect(video["author"].as_s).to eq("The Economist")
    expect(video["author_verified"].as_s).to eq("false")
    expect(video["length_seconds"].as_s).to eq(754.to_s)
    expect(video["short_view_count"].as_s).to eq("1.2K")
    expect(Time.parse_rfc3339(video["published"].as_s)).to be_close(Time.local - 21.days, 1.days)
  end

  it "ignores non-video lockups" do
    playlist_lockup = JSON.parse(%q({"contentType":"LOCKUP_CONTENT_TYPE_PLAYLIST","contentId":"PLtest"}))

    results = wrap_related_lockup([playlist_lockup]).dig?("secondaryResults", "secondaryResults", "results")

    related = Invidious::Videos::Parser.parse_related_videos(results)

    expect(related.size).to eq(0)
  end

  it "still parses legacy compactVideoRenderer items" do
    results = JSON.parse({
      "secondaryResults": {
        "secondaryResults": {
          "results": [{"compactVideoRenderer" => LEGACY_CVR_ITEM}],
        },
      },
    }.to_json).dig?("secondaryResults", "secondaryResults", "results")

    related = Invidious::Videos::Parser.parse_related_videos(results)

    expect(related.size).to eq(1)

    video = related[0].as_h
    expect(video["id"].as_s).to eq("aqz-KE-bpKQ")
    expect(video["ucid"].as_s).to eq("UCSMOQeBJ2RAnuFungnYDxuA")
    expect(video["length_seconds"].as_s).to eq((9*60 + 56).to_s)
  end
end
