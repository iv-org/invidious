module Invidious::Videos
  # Namespace for methods primarily relating to Transcripts
  module Transcript
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
  end
end
