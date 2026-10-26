require "../../parsers_helper.cr"

Spectator.describe "LockupViewModelParser channel videos" do
  def lockup_video(metadata_rows : Array(JSON::Any)) : JSON::Any
    JSON.parse({
      "lockupViewModel" => {
        "contentType"  => "LOCKUP_CONTENT_TYPE_VIDEO",
        "contentId"    => "video123",
        "contentImage" => {
          "thumbnailViewModel" => {
            "image" => {
              "sources" => [{"url" => "https://example.invalid/thumb.jpg"}],
            },
            "overlays" => [{
              "thumbnailBottomOverlayViewModel" => {
                "badges" => [{
                  "thumbnailBadgeViewModel" => {"text" => "12:34"},
                }],
              },
            }],
          },
        },
        "metadata" => {
          "lockupMetadataViewModel" => {
            "title"    => {"content" => "Collaboration video"},
            "metadata" => {
              "contentMetadataViewModel" => {
                "metadataRows" => metadata_rows.map(&.raw),
              },
            },
          },
        },
      },
    }.to_json)
  end

  it "parses a normal first-row metadata layout" do
    rows = [
      JSON.parse({
        "metadataParts" => [
          {"text" => {"content" => "1.5M views"}},
          {"text" => {"content" => "3 days ago"}},
        ],
      }.to_json),
    ]

    result = parse_item(lockup_video(rows), "Example", "UC123")
    expect(result).to be_a(SearchVideo)

    video = result.as(SearchVideo)
    expect(video.views).to eq(1_500_000)
    expect(video.published).to be_close(Time.utc - 3.days, 2.seconds)
    expect(video.length_seconds).to eq(754)
  end

  it "parses metadata after a collaboration author row" do
    rows = [
      JSON.parse({
        "metadataParts" => [
          {"text" => {"content" => "Example and Collaborator"}},
        ],
      }.to_json),
      JSON.parse({
        "metadataParts" => [
          {"text" => {"content" => "1.5M views"}},
          {"text" => {"content" => "3 days ago"}},
        ],
      }.to_json),
    ]

    result = parse_item(lockup_video(rows), "Example", "UC123")
    expect(result).to be_a(SearchVideo)

    video = result.as(SearchVideo)
    expect(video.views).to eq(1_500_000)
    expect(video.published).to be_close(Time.utc - 3.days, 2.seconds)
    expect(video.author).to eq("Example")
    expect(video.ucid).to eq("UC123")
  end

  it "skips metadata rows that do not contain metadataParts" do
    rows = [
      JSON.parse("{}"),
      JSON.parse({
        "metadataParts" => [
          {"text" => {"content" => "1.5M views"}},
          {"text" => {"content" => "3 days ago"}},
        ],
      }.to_json),
    ]

    result = parse_item(lockup_video(rows), "Example", "UC123")
    expect(result).to be_a(SearchVideo)

    video = result.as(SearchVideo)
    expect(video.views).to eq(1_500_000)
    expect(video.published).to be_close(Time.utc - 3.days, 2.seconds)
  end
end
