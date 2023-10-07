require "../../spec_helper.cr"

MockLines = [
  {
    "start_time": Time::Span.new(seconds: 1),
    "end_time":   Time::Span.new(seconds: 2),
    "text":       "Line 1",
  },

  {
    "start_time": Time::Span.new(seconds: 2),
    "end_time":   Time::Span.new(seconds: 3),
    "text":       "Line 2",
  },
]

Spectator.describe "WebVTT::Builder" do
  it "correctly builds a vtt file" do
    result = WebVTT.build do |vtt|
      MockLines.each do |line|
        vtt.cue(line["start_time"], line["end_time"], line["text"])
      end
    end

    expect(result).to eq([
      "WEBVTT",
      "",
      "00:00:01.000 --> 00:00:02.000",
      "Line 1",
      "",
      "00:00:02.000 --> 00:00:03.000",
      "Line 2",
      "",
      "",
    ].join('\n'))
  end

  it "correctly builds a vtt file with setting fields" do
    setting_fields = {
      "Kind"     => "captions",
      "Language" => "en",
    }

    result = WebVTT.build(setting_fields) do |vtt|
      MockLines.each do |line|
        vtt.cue(line["start_time"], line["end_time"], line["text"])
      end
    end

    expect(result).to eq([
      "WEBVTT",
      "Kind: captions",
      "Language: en",
      "",
      "00:00:01.000 --> 00:00:02.000",
      "Line 1",
      "",
      "00:00:02.000 --> 00:00:03.000",
      "Line 2",
      "",
      "",
    ].join('\n'))
  end
end
