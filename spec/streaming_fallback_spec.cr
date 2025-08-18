require "spectator"

# Bring in the helper under test
require "../src/invidious/videos/parser.cr"

Spectator.describe Invidious::Videos::ParserHelpers do
  def json_any_hash(h : Hash(String, JSON::Any))
    h
  end

  def json_any_array(a : Array(JSON::Any))
    JSON::Any.new(a)
  end

  def json_any_str(s : String)
    JSON::Any.new(s)
  end

  def json_any_obj(h : Hash(String, JSON::Any))
    JSON::Any.new(h)
  end

  it "patches formats when primary missing and fallback has usable formats" do
    primary_sd = {
      "formats"         => JSON::Any.new([] of JSON::Any),
      "adaptiveFormats" => JSON::Any.new([] of JSON::Any),
    } of String => JSON::Any

    fallback_sd = {
      "formats" => JSON::Any.new([
        JSON::Any.new({"url" => json_any_str("https://example.com/video.mp4")}),
      ] of JSON::Any),
      "adaptiveFormats" => JSON::Any.new([
        JSON::Any.new({"url" => json_any_str("https://example.com/audio.m4a")}),
      ] of JSON::Any),
    } of String => JSON::Any

    res = Invidious::Videos::ParserHelpers.patch_streaming_data_if_missing!(primary_sd, fallback_sd)

    expect(res[:patched_formats]).to be_true
    expect(res[:patched_adaptive]).to be_true

    # Ensure formats now have a non-empty URL
    first_fmt = primary_sd["formats"].as_a[0].as_h
    expect(first_fmt["url"].as_s).to_not be_empty
  end

  it "does not overwrite valid primary data" do
    primary_sd = {
      "formats" => JSON::Any.new([
        JSON::Any.new({"url" => json_any_str("https://primary/video.mp4")}),
      ] of JSON::Any),
      "adaptiveFormats" => JSON::Any.new([
        JSON::Any.new({"url" => json_any_str("https://primary/audio.m4a")}),
      ] of JSON::Any),
    } of String => JSON::Any

    fallback_sd = {
      "formats" => JSON::Any.new([
        JSON::Any.new({"url" => json_any_str("https://fallback/video.mp4")}),
      ] of JSON::Any),
      "adaptiveFormats" => JSON::Any.new([
        JSON::Any.new({"url" => json_any_str("https://fallback/audio.m4a")}),
      ] of JSON::Any),
    } of String => JSON::Any

    res = Invidious::Videos::ParserHelpers.patch_streaming_data_if_missing!(primary_sd, fallback_sd)

    expect(res[:patched_formats]).to be_false
    expect(res[:patched_adaptive]).to be_false

    # Primary values should remain
    expect(primary_sd["formats"].as_a[0].as_h["url"].as_s).to eq("https://primary/video.mp4")
    expect(primary_sd["adaptiveFormats"].as_a[0].as_h["url"].as_s).to eq("https://primary/audio.m4a")
  end

  it "handles fallback without formats gracefully" do
    primary_sd = {
      "formats"         => JSON::Any.new([] of JSON::Any),
      "adaptiveFormats" => JSON::Any.new([] of JSON::Any),
    } of String => JSON::Any

    fallback_sd = {
      "adaptiveFormats" => JSON::Any.new([
        JSON::Any.new({"url" => json_any_str("https://example.com/audio.m4a")}),
      ] of JSON::Any),
    } of String => JSON::Any

    res = Invidious::Videos::ParserHelpers.patch_streaming_data_if_missing!(primary_sd, fallback_sd)

    expect(res[:patched_adaptive]).to be_true
    expect(res[:patched_formats]).to be_false
  end
end
