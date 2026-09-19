require "../parsers_helper.cr"

private def lockup_video_with_metadata(metadata : String)
  JSON.parse(<<-JSON)
    {
      "lockupViewModel": {
        "contentType": "LOCKUP_CONTENT_TYPE_VIDEO",
        "contentId": "abcdefghijk",
        "contentImage": {
          "thumbnailViewModel": {
            "image": {"sources": [{"url": "https://i.ytimg.com/vi/abcdefghijk/hqdefault.jpg"}]},
            "overlays": [{"thumbnailBottomOverlayViewModel": {
              "badges": [{"thumbnailBadgeViewModel": {"text": "12:34"}}]
            }}]
          }
        },
        "metadata": {
          "lockupMetadataViewModel": {
            "title": {"content": "A collaboration"},
            "metadata": {"contentMetadataViewModel": #{metadata}}
          }
        }
      }
    }
    JSON
end

Spectator.describe "lockup video metadata rows" do
  sample({
    "normal first row"                                   => %({"metadataRows":[{"metadataParts":[{"text":{"content":"1.5M views"}},{"text":{"content":"3 days ago"}}]}]}),
    "collaborators before video statistics"              => %({"metadataRows":[{"metadataParts":[{"text":{"content":"Channel A and Channel B"}}]},{"metadataParts":[{"text":{"content":"1.5M views"}},{"text":{"content":"3 days ago"}}]}]}),
    "collaborator names containing statistic substrings" => %({"metadataRows":[{"metadataParts":[{"text":{"content":"Chicago Reviews"}},{"text":{"content":"Tech reviews"}}]},{"metadataParts":[{"text":{"content":"1.5M views"}},{"text":{"content":"3 days ago"}}]}]}),
    "views and publication date in separate rows"        => %({"metadataRows":[{"metadataParts":[{"text":{"content":"1.5M views"}}]},{"metadataParts":[{"text":{"content":"3 days ago"}}]}]}),
    "missing and null metadata parts before statistics"  => %({"metadataRows":[{},{"metadataParts":null},{"metadataParts":[{"text":{"content":"1.5M views"}},{"text":{"content":"3 days ago"}}]}]}),
    "icon labels before video statistics"                => %({"metadataRows":[{"metadataParts":[{"icon":{},"text":{"content":"99 views"}},{"icon":{},"text":{"content":"9 days ago"}}]},{"metadataParts":[{"text":{"content":"1.5M views"}},{"text":{"content":"3 days ago"}}]}]}),
  }) do |entry|
    it "parses the video statistics and preserves other metadata" do
      before = Time.utc - 3.days
      video = parse_item(lockup_video_with_metadata(entry[1]), "Channel A", "UCexample").as(SearchVideo)
      after = Time.utc - 3.days

      expect(video.views).to eq(1_500_000)
      expect(video.published).to be_between(before, after)
      expect(video.title).to eq("A collaboration")
      expect(video.id).to eq("abcdefghijk")
      expect(video.author).to eq("Channel A")
      expect(video.ucid).to eq("UCexample")
      expect(video.length_seconds).to eq(754)
    end
  end

  sample({"{}", %({"metadataRows":[]}), %({"metadataRows":null}), %({"metadataRows":[{}, {"metadataParts":null}]})}) do |metadata|
    it "keeps unknown statistics defaults" do
      before = Time.utc
      video = parse_item(lockup_video_with_metadata(metadata)).as(SearchVideo)
      after = Time.utc

      expect(video.views).to eq(0)
      expect(video.published).to be_between(before, after)
    end
  end
end
