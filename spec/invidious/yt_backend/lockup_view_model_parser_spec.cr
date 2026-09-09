require "../../parsers_helper.cr"

Spectator.describe "LockupViewModelParser channel videos" do
  # Minimal lockupViewModel shape used by channel video listings.
  def lockup_video(metadata_rows : Array(JSON::Any)) : JSON::Any
    JSON.parse({
      "lockupViewModel" => {
        "contentType"  => "LOCKUP_CONTENT_TYPE_VIDEO",
        "contentId"    => "dQw4w9WgXcQ",
        "contentImage" => {
          "thumbnailViewModel" => {
            "image" => {
              "sources" => [{"url" => "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"}],
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
            "title"    => {"content" => "Google Maps is unreasonably fast. Let me explain"},
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

  it "parses views and published from the first metadata row (non-collab)" do
    rows = [
      JSON.parse({
        "metadataParts" => [
          {"text" => {"content" => "1.5M views"}},
          {"text" => {"content" => "3 days ago"}},
        ],
      }.to_json),
    ]

    result = parse_item(lockup_video(rows), "Veritasium", "UCHnyfMqiRRG1u-2MsSQLbXA")
    expect(result).to be_a(SearchVideo)

    video = result.as(SearchVideo)
    expect(video.title).to eq("Google Maps is unreasonably fast. Let me explain")
    expect(video.id).to eq("dQw4w9WgXcQ")
    expect(video.views).to eq(1_500_000)
    expect(video.published).to be_close(Time.utc - 3.days, 2.seconds)
    expect(video.length_seconds).to eq(754)
  end

  it "parses views and published when collab authors occupy earlier metadata rows" do
    # Collaboration listings place co-authors in the first row(s); views/"ago" follow later.
    # Rows without metadataParts must be skipped without raising.
    rows = [
      JSON.parse("{}"),
      JSON.parse({
        "metadataParts" => [
          {
            "text" => {"content" => "Veritasium"},
            "icon" => {"name" => "CHECK_CIRCLE_FILLED"},
          },
          {
            "text" => {"content" => "and Linus Tech Tips"},
            "icon" => {"name" => "CHECK_CIRCLE_FILLED"},
          },
        ],
      }.to_json),
      JSON.parse({
        "metadataParts" => [
          {"text" => {"content" => "1.5M views"}},
          {"text" => {"content" => "3 days ago"}},
        ],
      }.to_json),
    ]

    result = parse_item(lockup_video(rows), "Veritasium", "UCHnyfMqiRRG1u-2MsSQLbXA")
    expect(result).to be_a(SearchVideo)

    video = result.as(SearchVideo)
    expect(video.views).to eq(1_500_000)
    expect(video.published).to be_close(Time.utc - 3.days, 2.seconds)
    expect(video.author).to eq("Veritasium")
    expect(video.ucid).to eq("UCHnyfMqiRRG1u-2MsSQLbXA")
  end
end
