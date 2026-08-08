require "../spec_helper"

Spectator.describe "parse_content" do
  it "sanitizes raw run text for emoji alt attributes if accessibility label is missing" do
    payload = JSON.parse(%({
      "runs": [
        {
          "text": "<script>alert(1)</script>",
          "emoji": {
            "image": {
              "thumbnails": [
                {
                  "url": "http://example.com/image.jpg",
                  "width": 24,
                  "height": 24
                }
              ]
            }
          }
        }
      ]
    }))

    result = parse_content(payload)
    expect(result).to contain("alt=\"&lt;script&gt;alert(1)&lt;/script&gt;\"")
    expect(result).to contain("title=\"&lt;script&gt;alert(1)&lt;/script&gt;\"")
    expect(result).to_not contain("<script>")
  end
end
