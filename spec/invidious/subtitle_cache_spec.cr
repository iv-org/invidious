require "../spec_helper"
require "../../src/invidious/user/preferences"
require "../../src/invidious/jobs/base_job"
require "../../src/invidious/jobs/*"
require "../../src/invidious/jobs"
require "../../src/invidious/config"

{% unless @top_level.has_constant?(:CONFIG) %}
  CONFIG = Config.from_yaml(File.open("config/config.example.yml"))
{% end %}

CONFIG.invidious_companion_key = "1234567890123456"

private def subtitle_response(status_code : Int32, content_type : String, body : String)
  headers = HTTP::Headers.new
  headers["Content-Type"] = content_type
  headers["Access-Control-Allow-Origin"] = "*"
  Invidious::SubtitleCache::Response.new(status_code, headers, body)
end

Spectator.describe Invidious::SubtitleCache do
  describe "check verification" do
    it "verifies valid tokens" do
      token = invidious_companion_encrypt("test_video_123")
      expect(invidious_companion_verify_check(token, "test_video_123")).to be_true
    end

    it "rejects tokens with mismatched video id" do
      token = invidious_companion_encrypt("test_video_123")
      expect(invidious_companion_verify_check(token, "other_video_456")).to be_false
    end

    it "rejects expired tokens older than 6 hours" do
      old_ts = Time.utc.to_unix - (7 * 3600)
      encrypted = encrypt_ecb_without_salt("#{old_ts}|test_video_123", CONFIG.invidious_companion_key)
      token = Base64.urlsafe_encode(encrypted)
      expect(invidious_companion_verify_check(token, "test_video_123")).to be_false
    end

    it "rejects malformed or empty tokens" do
      expect(invidious_companion_verify_check("", "test_video_123")).to be_false
      expect(invidious_companion_verify_check("invalid-base64-!@#$", "test_video_123")).to be_false
      expect(invidious_companion_verify_check("AAAA", "test_video_123")).to be_false
    end
  end

  describe "SubtitleCache operations" do
    it "correctly identifies valid WebVTT" do
      expect(Invidious::SubtitleCache.valid_vtt?("WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nHello")).to be_true
      expect(Invidious::SubtitleCache.valid_vtt?("\uFEFFWEBVTT\n\n00:00:00.000 --> 00:00:01.000\nHello")).to be_true
      expect(Invidious::SubtitleCache.valid_vtt?("  \nWEBVTT\n\n")).to be_true
      expect(Invidious::SubtitleCache.valid_vtt?("")).to be_false
      expect(Invidious::SubtitleCache.valid_vtt?("{\"error\": \"not found\"}")).to be_false
      expect(Invidious::SubtitleCache.valid_vtt?("<!DOCTYPE html><html></html>")).to be_false
    end

    it "stores and retrieves entries" do
      cache = Invidious::SubtitleCache.new
      vtt = "WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nTest cue\n"

      entry = cache.put("video:123|label:en", vtt, "text/vtt; charset=utf-8")
      expect(entry).not_to be_nil
      expect(cache.size).to eq(1)

      retrieved = cache.get("video:123|label:en")
      expect(retrieved).not_to be_nil
      expect(retrieved.try &.body).to eq(vtt)
    end

    it "isolates different languages and labels" do
      cache = Invidious::SubtitleCache.new
      vtt_en = "WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nEnglish\n"
      vtt_zh = "WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nChinese\n"

      cache.put("video:123|label:English|lang:en|tlang:", vtt_en, "text/vtt")
      cache.put("video:123|label:Chinese|lang:zh|tlang:", vtt_zh, "text/vtt")

      expect(cache.get("video:123|label:English|lang:en|tlang:").try &.body).to eq(vtt_en)
      expect(cache.get("video:123|label:Chinese|lang:zh|tlang:").try &.body).to eq(vtt_zh)
    end

    it "returns miss on first fetch and hit on subsequent fetch" do
      cache = Invidious::SubtitleCache.new
      fetch_count = 0
      vtt = "WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nHello"

      result1 = cache.get_or_fetch("video:abc") do
        fetch_count += 1
        subtitle_response(200, "text/vtt", vtt)
      end

      expect(result1.cache_status).to eq("miss")
      expect(result1.entry.try &.body).to eq(vtt)
      expect(fetch_count).to eq(1)

      result2 = cache.get_or_fetch("video:abc") do
        fetch_count += 1
        subtitle_response(200, "text/vtt", vtt)
      end

      expect(result2.cache_status).to eq("hit")
      expect(result2.entry.try &.body).to eq(vtt)
      expect(fetch_count).to eq(1)
    end

    it "coalesces concurrent fetches for the same key" do
      cache = Invidious::SubtitleCache.new
      fetch_count = 0
      vtt = "WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nCoalesced"
      done_ch = ::Channel(String).new(5)

      5.times do
        spawn do
          result = cache.get_or_fetch("video:concurrent") do
            fetch_count += 1
            sleep 0.05.seconds
            subtitle_response(200, "text/vtt", vtt)
          end
          done_ch.send(result.cache_status)
        end
      end

      results = Array(String).new
      5.times { results << done_ch.receive }

      expect(fetch_count).to eq(1)
      expect(results.count("miss")).to eq(1)
      expect(results.count("hit")).to eq(4)
    end

    it "evicts oldest entries when max_entries is exceeded (LRU)" do
      cache = Invidious::SubtitleCache.new(max_entries: 2)
      vtt = "WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nLine"

      cache.put("k1", vtt, "text/vtt")
      cache.put("k2", vtt, "text/vtt")
      expect(cache.size).to eq(2)

      # Access k1 to make it most recently used
      cache.get("k1")

      # Adding k3 should evict k2 (the oldest)
      cache.put("k3", vtt, "text/vtt")
      expect(cache.size).to eq(2)
      expect(cache.get("k1")).not_to be_nil
      expect(cache.get("k3")).not_to be_nil
      expect(cache.get("k2")).to be_nil
    end

    it "evicts oldest entries when max_bytes is exceeded" do
      cache = Invidious::SubtitleCache.new(max_entries: 10, max_bytes: 60)
      vtt1 = "WEBVTT\n\n12345678901234567890" # ~30 bytes
      vtt2 = "WEBVTT\n\nABCDEFGHIJABCDEFGHIJ" # ~30 bytes
      vtt3 = "WEBVTT\n\nXYZXYZXYZXYZXYZXYZ"   # ~27 bytes

      cache.put("k1", vtt1, "text/vtt")
      cache.put("k2", vtt2, "text/vtt")
      expect(cache.size).to eq(2)

      # Adding k3 pushes total bytes over 60, evicts k1
      cache.put("k3", vtt3, "text/vtt")
      expect(cache.get("k1")).to be_nil
      expect(cache.get("k2")).not_to be_nil
      expect(cache.get("k3")).not_to be_nil
    end

    it "does not cache failed or non-vtt responses" do
      cache = Invidious::SubtitleCache.new
      result = cache.get_or_fetch("video:bad") do
        subtitle_response(404, "application/json", "{\"error\":\"not found\"}")
      end

      expect(result.cache_status).to eq("bypass")
      expect(result.entry).to be_nil
      expect(result.response.try &.body).to eq("{\"error\":\"not found\"}")
      expect(result.response.try &.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(cache.size).to eq(0)
    end

    it "does not cache oversized fetch responses" do
      cache = Invidious::SubtitleCache.new
      oversized = "WEBVTT\n" + ("x" * (Invidious::SubtitleCache::MAX_ENTRY_BYTES + 1))

      result = cache.get_or_fetch("video:oversized") do
        subtitle_response(200, "text/vtt", oversized)
      end

      expect(result.cache_status).to eq("bypass")
      expect(result.entry).to be_nil
      expect(result.response.try &.body).to eq(oversized)
      expect(cache.size).to eq(0)
    end
  end
end
