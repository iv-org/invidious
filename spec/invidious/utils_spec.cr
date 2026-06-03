require "../spec_helper"

Spectator.describe "Utils" do
  describe "audio_bitrate_label" do
    it "formats audio bitrates as kbps labels" do
      expect(audio_bitrate_label(128000)).to eq("128 kbps")
      expect(audio_bitrate_label(129003)).to eq("129 kbps")
    end
  end

  describe "audio_quality_label_to_bitrate" do
    it "parses the current kbps label format" do
      expect(audio_quality_label_to_bitrate("128 kbps")).to eq(128000)
    end

    it "keeps legacy k-suffixed labels compatible" do
      expect(audio_quality_label_to_bitrate("128k")).to eq(128000)
      expect(audio_quality_label_to_bitrate("128000k")).to eq(128000)
    end

    it "ignores unrelated quality labels" do
      expect(audio_quality_label_to_bitrate("medium")).to be_nil
      expect(audio_quality_label_to_bitrate("dash")).to be_nil
    end
  end

  describe "decode_date" do
    it "parses short dates (en-US)" do
      expect(decode_date("1s ago")).to be_close(Time.utc - 1.second, 500.milliseconds)
      expect(decode_date("2min ago")).to be_close(Time.utc - 2.minutes, 500.milliseconds)
      expect(decode_date("3h ago")).to be_close(Time.utc - 3.hours, 500.milliseconds)
      expect(decode_date("4d ago")).to be_close(Time.utc - 4.days, 500.milliseconds)
      expect(decode_date("5w ago")).to be_close(Time.utc - 5.weeks, 500.milliseconds)
      expect(decode_date("6mo ago")).to be_close(Time.utc - 6.months, 500.milliseconds)
      expect(decode_date("7y ago")).to be_close(Time.utc - 7.years, 500.milliseconds)
    end

    it "parses short dates (en-GB)" do
      expect(decode_date("55s ago")).to be_close(Time.utc - 55.seconds, 500.milliseconds)
      expect(decode_date("44min ago")).to be_close(Time.utc - 44.minutes, 500.milliseconds)
      expect(decode_date("22hr ago")).to be_close(Time.utc - 22.hours, 500.milliseconds)
      expect(decode_date("1day ago")).to be_close(Time.utc - 1.day, 500.milliseconds)
      expect(decode_date("2days ago")).to be_close(Time.utc - 2.days, 500.milliseconds)
      expect(decode_date("3wk ago")).to be_close(Time.utc - 3.weeks, 500.milliseconds)
      expect(decode_date("11mo ago")).to be_close(Time.utc - 11.months, 500.milliseconds)
      expect(decode_date("11yr ago")).to be_close(Time.utc - 11.years, 500.milliseconds)
    end

    it "parses long forms (singular)" do
      expect(decode_date("1 second ago")).to be_close(Time.utc - 1.second, 500.milliseconds)
      expect(decode_date("1 minute ago")).to be_close(Time.utc - 1.minute, 500.milliseconds)
      expect(decode_date("1 hour ago")).to be_close(Time.utc - 1.hour, 500.milliseconds)
      expect(decode_date("1 day ago")).to be_close(Time.utc - 1.day, 500.milliseconds)
      expect(decode_date("1 week ago")).to be_close(Time.utc - 1.week, 500.milliseconds)
      expect(decode_date("1 month ago")).to be_close(Time.utc - 1.month, 500.milliseconds)
      expect(decode_date("1 year ago")).to be_close(Time.utc - 1.year, 500.milliseconds)
    end

    it "parses long forms (plural)" do
      expect(decode_date("5 seconds ago")).to be_close(Time.utc - 5.seconds, 500.milliseconds)
      expect(decode_date("17 minutes ago")).to be_close(Time.utc - 17.minutes, 500.milliseconds)
      expect(decode_date("23 hours ago")).to be_close(Time.utc - 23.hours, 500.milliseconds)
      expect(decode_date("3 days ago")).to be_close(Time.utc - 3.days, 500.milliseconds)
      expect(decode_date("2 weeks ago")).to be_close(Time.utc - 2.weeks, 500.milliseconds)
      expect(decode_date("9 months ago")).to be_close(Time.utc - 9.months, 500.milliseconds)
      expect(decode_date("8 years ago")).to be_close(Time.utc - 8.years, 500.milliseconds)
    end
  end
end
