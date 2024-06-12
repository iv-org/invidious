module Invidious::Videos
  # A `Transcripts` struct encapsulates a sequence of lines that together forms the whole transcript for a given YouTube video.
  # These lines can be categorized into two types: section headings and regular lines representing content from the video.
  struct Transcript
    # Types
    record HeadingLine, start_ms : Time::Span, end_ms : Time::Span, line : String
    record RegularLine, start_ms : Time::Span, end_ms : Time::Span, line : String
    alias TranscriptLine = HeadingLine | RegularLine

    property lines : Array(TranscriptLine)
    property language_code : String
    property auto_generated : Bool

    # Initializes a new Transcript struct with the contents and associated metadata describing it
    def initialize(@lines : Array(TranscriptLine), @language_code : String, @auto_generated : Bool)
    end

    # Generates a protobuf string to fetch the requested transcript from YouTube
    def self.generate_param(video_id : String, language_code : String, auto_generated : Bool) : String
      kind = auto_generated ? "asr" : ""

      object = {
        "1:0:string" => video_id,

        "2:base64" => {
          "1:string" => kind,
          "2:string" => language_code,
          "3:string" => "",
        },

        "3:varint" => 1_i64,
        "5:string" => "engagement-panel-searchable-transcript-search-panel",
        "6:varint" => 1_i64,
        "7:varint" => 1_i64,
        "8:varint" => 1_i64,
      }

      params = object.try { |i| Protodec::Any.cast_json(i) }
        .try { |i| Protodec::Any.from_json(i) }
        .try { |i| Base64.urlsafe_encode(i) }
        .try { |i| URI.encode_www_form(i) }

      return params
    end

    # Constructs a Transcripts struct from the initial YouTube response
    def self.from_raw(initial_data : Hash(String, JSON::Any), language_code : String, auto_generated : Bool)
      body = initial_data.dig("actions", 0, "updateEngagementPanelAction", "content", "transcriptRenderer",
        "content", "transcriptSearchPanelRenderer", "body", "transcriptSegmentListRenderer",
        "initialSegments").as_a

      lines = [] of TranscriptLine

      body.each do |line|
        if unpacked_line = line["transcriptSectionHeaderRenderer"]?
          line_type = HeadingLine
        else
          unpacked_line = line["transcriptSegmentRenderer"]
          line_type = RegularLine
        end

        start_ms = unpacked_line["startMs"].as_s.to_i.millisecond
        end_ms = unpacked_line["endMs"].as_s.to_i.millisecond
        text = extract_text(unpacked_line["snippet"]) || ""

        lines << line_type.new(start_ms, end_ms, text)
      end

      return Transcript.new(
        lines: lines,
        language_code: language_code,
        auto_generated: auto_generated,
      )
    end

    # Converts transcript lines to a WebVTT file
    #
    # This is used within Invidious to replace subtitles
    # as to workaround YouTube's rate-limited timedtext endpoint.
    def to_vtt
      settings_field = {
        "Kind"     => "captions",
        "Language" => @language_code,
      }

      vtt = WebVTT.build(settings_field) do |vtt|
        @lines.each do |line|
          # Section headers are excluded from the VTT conversion as to
          # match the regular captions returned from YouTube as much as possible
          next if line.is_a? HeadingLine

          vtt.cue(line.start_ms, line.end_ms, line.line)
        end
      end

      return vtt
    end
  end
end
