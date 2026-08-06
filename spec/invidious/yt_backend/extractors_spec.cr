require "../../parsers_helper"

Spectator.describe "YouTubeTabs" do
  it "treats a selected tab without content as empty" do
    initdata = JSON.parse(<<-JSON).as_h
      {
        "contents": {
          "twoColumnBrowseResultsRenderer": {
            "tabs": [
              {"tabRenderer": {"selected": true}}
            ]
          }
        }
      }
      JSON

    items, continuation = extract_items(initdata)

    expect(items).to be_empty
    expect(continuation).to be_nil
  end
end
