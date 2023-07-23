module Invidious::Videos
  # Namespace for methods primarily relating to Transcripts
  module Transcript
    record TranscriptLine, start_ms : Time::Span, end_ms : Time::Span, line : String

    def self.generate_param(video_id : String, language_code : String, auto_generated : Bool) : String
      if !auto_generated
        is_auto_generated = ""
      elsif is_auto_generated = "asr"
      end

      object = {
        "1:0:string" => video_id,

        "2:base64" => {
          "1:string" => is_auto_generated,
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

    def self.convert_transcripts_to_vtt(initial_data : JSON::Any, target_language : String) : String
      # Convert into TranscriptLine

      vtt = String.build do |vtt|
        result << <<-END_VTT
        WEBVTT
        Kind: captions
        Language: #{tlang}


        END_VTT

        vtt << "\n\n"
      end
    end

    def self.parse(initial_data : Hash(String, JSON::Any))
      body = initial_data.dig("actions", 0, "updateEngagementPanelAction", "content", "transcriptRenderer",
        "content", "transcriptSearchPanelRenderer", "body", "transcriptSegmentListRenderer",
        "initialSegments").as_a

      lines = [] of TranscriptLine
      body.each do |line|
        line = line["transcriptSegmentRenderer"]
        start_ms = line["startMs"].as_s.to_i.millisecond
        end_ms = line["endMs"].as_s.to_i.millisecond

        text = extract_text(line["snippet"]) || ""

        lines << TranscriptLine.new(start_ms, end_ms, text)
      end

      return lines
    end
  end
end
