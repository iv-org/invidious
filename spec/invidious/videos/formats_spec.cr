require "json"
require "spectator"
require "../../../src/invidious/videos/formats"

Spectator.describe Invidious::Videos::Formats do
  describe ".audio_quality_label" do
    it "uses the known audio bitrate for mapped itags" do
      fmt = {
        "itag"    => JSON::Any.new(140_i64),
        "bitrate" => JSON::Any.new(128_619_i64),
      }

      expect(Invidious::Videos::Formats.audio_quality_label(fmt)).to eq("128 kbps")
    end

    it "falls back to a rounded bitrate for unknown itags" do
      fmt = {
        "itag"    => JSON::Any.new(123_456_i64),
        "bitrate" => JSON::Any.new(70_499_i64),
      }

      expect(Invidious::Videos::Formats.audio_quality_label(fmt)).to eq("70 kbps")
    end
  end
end
