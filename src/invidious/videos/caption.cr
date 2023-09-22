require "json"

module Invidious::Videos
  module Captions
    struct Metadata
      property name : String
      property language_code : String
      property base_url : String

      property auto_generated : Bool

      def initialize(@name, @language_code, @base_url, @auto_generated)
      end

      # Parse the JSON structure from Youtube
      def self.from_yt_json(container : JSON::Any) : Array(Captions::Metadata)
        caption_tracks = container
          .dig?("playerCaptionsTracklistRenderer", "captionTracks")
          .try &.as_a

        captions_list = [] of Captions::Metadata
        return captions_list if caption_tracks.nil?

        caption_tracks.each do |caption|
          name = caption["name"]["simpleText"]? || caption["name"]["runs"][0]["text"]
          name = name.to_s.split(" - ")[0]

          language_code = caption["languageCode"].to_s
          base_url = caption["baseUrl"].to_s

          auto_generated = (caption["kind"]? == "asr")

          captions_list << Captions::Metadata.new(name, language_code, base_url, auto_generated)
        end

        return captions_list
      end

      def timedtext_to_vtt(timedtext : String, tlang = nil) : String
        # In the future, we could just directly work with the url. This is more of a POC
        cues = [] of XML::Node
        tree = XML.parse(timedtext)
        tree = tree.children.first

        tree.children.each do |item|
          if item.name == "body"
            item.children.each do |cue|
              if cue.name == "p" && !(cue.children.size == 1 && cue.children[0].content == "\n")
                cues << cue
              end
            end
            break
          end
        end
        result = String.build do |result|
          result << <<-END_VTT
          WEBVTT
          Kind: captions
          Language: #{tlang || @language_code}


          END_VTT

          result << "\n\n"

          cues.each_with_index do |node, i|
            start_time = node["t"].to_f.milliseconds

            duration = node["d"]?.try &.to_f.milliseconds

            duration ||= start_time

            if cues.size > i + 1
              end_time = cues[i + 1]["t"].to_f.milliseconds
            else
              end_time = start_time + duration
            end

            # start_time
            result << start_time.hours.to_s.rjust(2, '0')
            result << ':' << start_time.minutes.to_s.rjust(2, '0')
            result << ':' << start_time.seconds.to_s.rjust(2, '0')
            result << '.' << start_time.milliseconds.to_s.rjust(3, '0')

            result << " --> "

            # end_time
            result << end_time.hours.to_s.rjust(2, '0')
            result << ':' << end_time.minutes.to_s.rjust(2, '0')
            result << ':' << end_time.seconds.to_s.rjust(2, '0')
            result << '.' << end_time.milliseconds.to_s.rjust(3, '0')

            result << "\n"

            node.children.each do |s|
              result << s.content
            end
            result << "\n"
            result << "\n"
          end
        end
        return result
      end
    end

    # List of all caption languages available on Youtube.
    LANGUAGES = {
      "",
      "English",
      "English (auto-generated)",
      "English (United Kingdom)",
      "English (United States)",
      "Afrikaans",
      "Albanian",
      "Amharic",
      "Arabic",
      "Armenian",
      "Azerbaijani",
      "Bangla",
      "Basque",
      "Belarusian",
      "Bosnian",
      "Bulgarian",
      "Burmese",
      "Cantonese (Hong Kong)",
      "Catalan",
      "Cebuano",
      "Chinese",
      "Chinese (China)",
      "Chinese (Hong Kong)",
      "Chinese (Simplified)",
      "Chinese (Taiwan)",
      "Chinese (Traditional)",
      "Corsican",
      "Croatian",
      "Czech",
      "Danish",
      "Dutch",
      "Dutch (auto-generated)",
      "Esperanto",
      "Estonian",
      "Filipino",
      "Finnish",
      "French",
      "French (auto-generated)",
      "Galician",
      "Georgian",
      "German",
      "German (auto-generated)",
      "Greek",
      "Gujarati",
      "Haitian Creole",
      "Hausa",
      "Hawaiian",
      "Hebrew",
      "Hindi",
      "Hmong",
      "Hungarian",
      "Icelandic",
      "Igbo",
      "Indonesian",
      "Indonesian (auto-generated)",
      "Interlingue",
      "Irish",
      "Italian",
      "Italian (auto-generated)",
      "Japanese",
      "Japanese (auto-generated)",
      "Javanese",
      "Kannada",
      "Kazakh",
      "Khmer",
      "Korean",
      "Korean (auto-generated)",
      "Kurdish",
      "Kyrgyz",
      "Lao",
      "Latin",
      "Latvian",
      "Lithuanian",
      "Luxembourgish",
      "Macedonian",
      "Malagasy",
      "Malay",
      "Malayalam",
      "Maltese",
      "Maori",
      "Marathi",
      "Mongolian",
      "Nepali",
      "Norwegian Bokmål",
      "Nyanja",
      "Pashto",
      "Persian",
      "Polish",
      "Portuguese",
      "Portuguese (auto-generated)",
      "Portuguese (Brazil)",
      "Punjabi",
      "Romanian",
      "Russian",
      "Russian (auto-generated)",
      "Samoan",
      "Scottish Gaelic",
      "Serbian",
      "Shona",
      "Sindhi",
      "Sinhala",
      "Slovak",
      "Slovenian",
      "Somali",
      "Southern Sotho",
      "Spanish",
      "Spanish (auto-generated)",
      "Spanish (Latin America)",
      "Spanish (Mexico)",
      "Spanish (Spain)",
      "Sundanese",
      "Swahili",
      "Swedish",
      "Tajik",
      "Tamil",
      "Telugu",
      "Thai",
      "Turkish",
      "Turkish (auto-generated)",
      "Ukrainian",
      "Urdu",
      "Uzbek",
      "Vietnamese",
      "Vietnamese (auto-generated)",
      "Welsh",
      "Western Frisian",
      "Xhosa",
      "Yiddish",
      "Yoruba",
      "Zulu",
    }
  end
end
