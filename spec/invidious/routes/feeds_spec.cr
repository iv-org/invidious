require "../../spec_helper"

Spectator.describe "Feeds" do
  describe "#add_video_query_params" do
    it "does not append an empty query separator" do
      request_target = "/watch?v=7uQOBLCcp3I"
      params = HTTP::Params.parse("")

      expect(add_video_query_params(request_target, params)).to eq(request_target)
    end

    it "appends non-empty params to watch links" do
      request_target = "/watch?v=7uQOBLCcp3I"
      params = HTTP::Params.parse("listen=1")

      expect(add_video_query_params(request_target, params)).to eq("#{request_target}&listen=1")
    end

    it "leaves non-watch links unchanged" do
      request_target = "/vi/7uQOBLCcp3I/hqdefault.jpg"
      params = HTTP::Params.parse("listen=1")

      expect(add_video_query_params(request_target, params)).to eq(request_target)
    end
  end
end
