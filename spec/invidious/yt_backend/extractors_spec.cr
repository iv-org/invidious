require "../../parsers_helper"

Spectator.describe HelperExtractors do
  describe ".get_browse_id" do
    it "extracts a direct browse endpoint" do
      container = JSON.parse(%(
        {
          "navigationEndpoint": {
            "browseEndpoint": {
              "browseId": "UCdirect"
            }
          }
        }
      ))

      expect(HelperExtractors.get_browse_id(container)).to eq("UCdirect")
    end

    it "returns an empty string when no browse endpoint exists" do
      container = JSON.parse(%({"navigationEndpoint":{"showDialogCommand":{}}}))

      expect(HelperExtractors.get_browse_id(container)).to be_empty
    end
  end
end
