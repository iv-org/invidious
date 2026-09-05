require "../../spec_helper"

Spectator.describe Invidious::Videos::Captions do
  describe ".matching" do
    it "matches English to English auto-generated ahead of other auto tracks" do
      arabic = Invidious::Videos::Captions::Metadata.new("Arabic (auto-generated)", "ar", "http://x", true)
      english_auto = Invidious::Videos::Captions::Metadata.new("English (auto-generated)", "en", "http://x", true)

      matched = Invidious::Videos::Captions.matching([arabic, english_auto], ["English"])
      expect(matched.map(&.name)).to eq(["English (auto-generated)"])
    end

    it "prefers a human English track over auto-generated English" do
      english_auto = Invidious::Videos::Captions::Metadata.new("English (auto-generated)", "en", "http://x", true)
      english = Invidious::Videos::Captions::Metadata.new("English", "en", "http://x", false)

      matched = Invidious::Videos::Captions.matching([english_auto, english], ["English"])
      expect(matched.map(&.name)).to eq(["English", "English (auto-generated)"])
    end

    it "matches regional English names and language codes" do
      us = Invidious::Videos::Captions::Metadata.new("English (United States)", "en-US", "http://x", false)
      uk = Invidious::Videos::Captions::Metadata.new("English (United Kingdom)", "en-GB", "http://x", false)
      german = Invidious::Videos::Captions::Metadata.new("German (Germany)", "de-DE", "http://x", false)

      matched = Invidious::Videos::Captions.matching([german, us, uk], ["English", "en"])
      expect(matched.map(&.name)).to eq(["English (United States)", "English (United Kingdom)"])
    end

    it "ignores blank preference slots" do
      arabic = Invidious::Videos::Captions::Metadata.new("Arabic (auto-generated)", "ar", "http://x", true)
      matched = Invidious::Videos::Captions.matching([arabic], ["", "", ""])
      expect(matched).to be_empty
    end
  end
end
