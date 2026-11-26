require "json"
require "spectator"
require "../../src/invidious/routes/proxy"

Spectator.describe Invidious::Routes::Proxy do
  describe ".host_allowed?" do
    it "allows the YouTube/Google hosts used by the SABR player" do
      {
        "rr1---sn-4g5e6nzz.googlevideo.com",
        "redirector.googlevideo.com",
        "www.youtube.com",
        "i.ytimg.com",
        "yt3.ggpht.com",
        "jnn-pa.googleapis.com",
        "www.google.com",
        "www.gstatic.com",
      }.each do |host|
        expect(Invidious::Routes::Proxy.host_allowed?(host)).to be_true
      end
    end

    it "rejects other hosts, including newline and suffix tricks" do
      {
        ".googlevideo.com\n",
        "rr1.googlevideo.com\n",
        "evil.com\n.googlevideo.com",
        "googlevideo.com.evil.com",
        "evilgooglevideo.com",
        "example.com",
        "googleapis.com",
        "www.googleapis.com",
        "rr1.googlevideo.com:8080",
        "rr1.googlevideo.com/path",
      }.each do |host|
        expect(Invidious::Routes::Proxy.host_allowed?(host)).to be_false
      end
    end
  end

  describe ".header_allowed?" do
    it "allows the headers sent by youtubei.js and the SABR player" do
      {
        "Content-Type", "accept", "X-Goog-Visitor-Id", "x-goog-api-key",
        "X-Youtube-Client-Name", "X-Youtube-Client-Version", "X-Origin",
        "x-user-agent", "User-Agent", "Range",
      }.each do |name|
        expect(Invidious::Routes::Proxy.header_allowed?(name)).to be_true
      end
    end

    it "rejects sensitive and hop-by-hop headers" do
      {
        "Cookie", "Host", "Connection", "X-Forwarded-For", "Proxy-Authorization",
        "Authorization", "Transfer-Encoding", "Content-Length", "Accept-Encoding",
      }.each do |name|
        expect(Invidious::Routes::Proxy.header_allowed?(name)).to be_false
      end
    end
  end

  describe ".valid_header?" do
    it "rejects control characters in header names and values" do
      expect(Invidious::Routes::Proxy.valid_header?("X-Goog-Visitor-Id", "Cgt4")).to be_true
      expect(Invidious::Routes::Proxy.valid_header?("X-Goog-Visitor-Id", "a\r\nHost: evil")).to be_false
      expect(Invidious::Routes::Proxy.valid_header?("X-Goog\r\nHost", "a")).to be_false
      expect(Invidious::Routes::Proxy.valid_header?("X Goog", "a")).to be_false
    end
  end

  describe "VALID_PATH" do
    it "accepts paths and rejects whitespace and control characters" do
      expect(Invidious::Routes::Proxy::VALID_PATH.matches?("/videoplayback")).to be_true
      expect(Invidious::Routes::Proxy::VALID_PATH.matches?("/youtubei/v1/player")).to be_true
      expect(Invidious::Routes::Proxy::VALID_PATH.matches?("/js/th/$abc/x.js")).to be_true
      expect(Invidious::Routes::Proxy::VALID_PATH.matches?("/a b")).to be_false
      expect(Invidious::Routes::Proxy::VALID_PATH.matches?("/a\r\nHost: evil")).to be_false
      expect(Invidious::Routes::Proxy::VALID_PATH.matches?("/a\n")).to be_false
      expect(Invidious::Routes::Proxy::VALID_PATH.matches?("noslash")).to be_false
    end
  end
end
