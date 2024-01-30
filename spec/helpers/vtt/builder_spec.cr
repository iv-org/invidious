require "../../spec_helper.cr"

MockLines                       = ["Line 1", "Line 2"]
MockLinesWithEscapableCharacter = ["<Line 1>", "&Line 2>", '\u200E' + "Line\u200F 3", "\u00A0Line 4"]

Spectator.describe "WebVTT::Builder" do
  it "correctly builds a vtt file" do
    result = WebVTT.build do |vtt|
      2.times do |i|
        vtt.cue(
          Time::Span.new(seconds: i),
          Time::Span.new(seconds: i + 1),
          MockLines[i]
        )
      end
    end

    expect(result).to eq([
      "WEBVTT",
      "",
      "00:00:00.000 --> 00:00:01.000",
      "Line 1",
      "",
      "00:00:01.000 --> 00:00:02.000",
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
      2.times do |i|
        vtt.cue(
          Time::Span.new(seconds: i),
          Time::Span.new(seconds: i + 1),
          MockLines[i]
        )
      end
    end

    expect(result).to eq([
      "WEBVTT",
      "Kind: captions",
      "Language: en",
      "",
      "00:00:00.000 --> 00:00:01.000",
      "Line 1",
      "",
      "00:00:01.000 --> 00:00:02.000",
      "Line 2",
      "",
      "",
    ].join('\n'))
  end

  it "properly escapes characters" do
    result = WebVTT.build do |vtt|
      4.times do |i|
        vtt.cue(Time::Span.new(seconds: i), Time::Span.new(seconds: i + 1), MockLinesWithEscapableCharacter[i])
      end
    end

    expect(result).to eq([
      "WEBVTT",
      "",
      "00:00:00.000 --> 00:00:01.000",
      "&lt;Line 1&gt;",
      "",
      "00:00:01.000 --> 00:00:02.000",
      "&amp;Line 2&gt;",
      "",
      "00:00:02.000 --> 00:00:03.000",
      "&lrm;Line&rlm; 3",
      "",
      "00:00:03.000 --> 00:00:04.000",
      "&nbsp;Line 4",
      "",
      "",
    ].join('\n'))
  end
end
