module Invidious::Videos
  # Namespace for methods primarily relating to Transcripts
  module Transcript
    record TranscriptLine, start_ms : Time::Span, end_ms : Time::Span, line : String

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

    def self.convert_transcripts_to_vtt(initial_data : Hash(String, JSON::Any), target_language : String) : String
      # Convert into array of TranscriptLine
      lines = self.parse(initial_data)

      # Taken from Invidious::Videos::Captions::Metadata.timedtext_to_vtt()
      vtt = String.build do |vtt|
        vtt << <<-END_VTT
        WEBVTT
        Kind: captions
        Language: #{target_language}


        END_VTT

        vtt << "\n\n"

        lines.each do |line|
          start_time = line.start_ms
          end_time = line.end_ms

          # start_time
          vtt << start_time.hours.to_s.rjust(2, '0')
          vtt << ':' << start_time.minutes.to_s.rjust(2, '0')
          vtt << ':' << start_time.seconds.to_s.rjust(2, '0')
          vtt << '.' << start_time.milliseconds.to_s.rjust(3, '0')

          vtt << " --> "

          # end_time
          vtt << end_time.hours.to_s.rjust(2, '0')
          vtt << ':' << end_time.minutes.to_s.rjust(2, '0')
          vtt << ':' << end_time.seconds.to_s.rjust(2, '0')
          vtt << '.' << end_time.milliseconds.to_s.rjust(3, '0')

          vtt << "\n"
          vtt << line.line

          vtt << "\n"
          vtt << "\n"
        end
      end

      return vtt
    end

    private def self.parse(initial_data : Hash(String, JSON::Any))
      body = initial_data.dig("actions", 0, "updateEngagementPanelAction", "content", "transcriptRenderer",
        "content", "transcriptSearchPanelRenderer", "body", "transcriptSegmentListRenderer",
        "initialSegments").as_a

      lines = [] of TranscriptLine
      body.each do |line|
        # Transcript section headers. They are not apart of the captions and as such we can safely skip them.
        if line.as_h.has_key?("transcriptSectionHeaderRenderer")
          next
        end

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
