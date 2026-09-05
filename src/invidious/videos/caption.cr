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

        settings_field = {
          "Kind"     => "captions",
          "Language" => "#{tlang || @language_code}",
        }

        result = WebVTT.build(settings_field) do |vtt|
          cues.each_with_index do |node, i|
            start_time = node["t"].to_f.milliseconds

            duration = node["d"]?.try &.to_f.milliseconds

            duration ||= start_time

            if cues.size > i + 1
              end_time = cues[i + 1]["t"].to_f.milliseconds
            else
              end_time = start_time + duration
            end

            text = String.build do |io|
              node.children.each do |s|
                io << s.content
              end
            end

            vtt.cue(start_time, end_time, text)
          end
        end

        return result
      end
    end

    # Tracks whose name or language matches the user's caption preferences,
    # ranked by preference slot then human tracks before auto-generated.
    def self.matching(captions : Array(Metadata), names : Array(String)) : Array(Metadata)
      wanted = names.map(&.strip).reject(&.empty?)
      return [] of Metadata if wanted.empty?

      selected = captions.select { |caption| matches?(caption, wanted) }
      selected.sort_by! { |caption| rank(caption, wanted) }
      selected
    end

    def self.matches?(caption : Metadata, names : Array(String)) : Bool
      names.any? { |name| name_matches?(caption, name) }
    end

    # Map display-language preferences (e.g. "English") onto ISO-ish codes so
    # they can match caption names/codes like "en" or "en-US".
    NAME_TO_CODE = {
      "afrikaans"          => "af",
      "albanian"           => "sq",
      "amharic"            => "am",
      "arabic"             => "ar",
      "armenian"           => "hy",
      "azerbaijani"        => "az",
      "bangla"             => "bn",
      "basque"             => "eu",
      "belarusian"         => "be",
      "bosnian"            => "bs",
      "bulgarian"          => "bg",
      "burmese"            => "my",
      "cantonese"          => "yue",
      "catalan"            => "ca",
      "cebuano"            => "ceb",
      "chinese"            => "zh",
      "corsican"           => "co",
      "croatian"           => "hr",
      "czech"              => "cs",
      "danish"             => "da",
      "dutch"              => "nl",
      "english"            => "en",
      "esperanto"          => "eo",
      "estonian"           => "et",
      "filipino"           => "fil",
      "finnish"            => "fi",
      "french"             => "fr",
      "galician"           => "gl",
      "georgian"           => "ka",
      "german"             => "de",
      "greek"              => "el",
      "gujarati"           => "gu",
      "haitian creole"     => "ht",
      "hausa"              => "ha",
      "hawaiian"           => "haw",
      "hebrew"             => "he",
      "hindi"              => "hi",
      "hmong"              => "hmn",
      "hungarian"          => "hu",
      "icelandic"          => "is",
      "igbo"               => "ig",
      "indonesian"         => "id",
      "interlingue"        => "ie",
      "irish"              => "ga",
      "italian"            => "it",
      "japanese"           => "ja",
      "javanese"           => "jv",
      "kannada"            => "kn",
      "kazakh"             => "kk",
      "khmer"              => "km",
      "korean"             => "ko",
      "kurdish"            => "ku",
      "kyrgyz"             => "ky",
      "lao"                => "lo",
      "latin"              => "la",
      "latvian"            => "lv",
      "lithuanian"         => "lt",
      "luxembourgish"      => "lb",
      "macedonian"         => "mk",
      "malagasy"           => "mg",
      "malay"              => "ms",
      "malayalam"          => "ml",
      "maltese"            => "mt",
      "maori"              => "mi",
      "marathi"            => "mr",
      "mongolian"          => "mn",
      "nepali"             => "ne",
      "norwegian bokmål"   => "nb",
      "norwegian bokmal"   => "nb",
      "nyanja"             => "ny",
      "pashto"             => "ps",
      "persian"            => "fa",
      "polish"             => "pl",
      "portuguese"         => "pt",
      "punjabi"            => "pa",
      "romanian"           => "ro",
      "russian"            => "ru",
      "samoan"             => "sm",
      "scottish gaelic"    => "gd",
      "serbian"            => "sr",
      "shona"              => "sn",
      "sindhi"             => "sd",
      "sinhala"            => "si",
      "slovak"             => "sk",
      "slovenian"          => "sl",
      "somali"             => "so",
      "southern sotho"     => "st",
      "spanish"            => "es",
      "sundanese"          => "su",
      "swahili"            => "sw",
      "swedish"            => "sv",
      "tajik"              => "tg",
      "tamil"              => "ta",
      "telugu"             => "te",
      "thai"               => "th",
      "turkish"            => "tr",
      "ukrainian"          => "uk",
      "urdu"               => "ur",
      "uzbek"              => "uz",
      "vietnamese"         => "vi",
      "welsh"              => "cy",
      "western frisian"    => "fy",
      "xhosa"              => "xh",
      "yiddish"            => "yi",
      "yoruba"             => "yo",
      "zulu"               => "zu",
    }

    private def self.name_matches?(caption : Metadata, name : String) : Bool
      needle = name.strip.downcase
      return false if needle.empty?

      caption_name = caption.name.downcase
      lang = caption.language_code.downcase
      base_lang = lang.split("-")[0]

      return true if caption_name == needle ||
                     caption_name.starts_with?(needle + " (") ||
                     caption_name.starts_with?(needle + " - ") ||
                     lang == needle ||
                     base_lang == needle

      # Display-language preferences such as "English" must also match
      # code-labeled tracks like "en" / "en-US".
      needle_codes = canonical_codes(needle)
      caption_codes = canonical_codes(caption_name)
      caption_codes << lang
      caption_codes << base_lang
      needle_codes.any? { |code| caption_codes.includes?(code) }
    end

    private def self.canonical_codes(value : String) : Array(String)
      raw = value.strip.downcase
      return [] of String if raw.empty?

      codes = [] of String
      base_name = raw.split(" - ")[0].split(" (")[0].strip

      if mapped = NAME_TO_CODE[base_name]?
        codes << mapped
      end

      if raw.includes?("-")
        codes << raw
        codes << raw.split("-")[0]
      elsif raw.size.in?(2..3) && raw.chars.all?(&.ascii_letter?)
        codes << raw
      end

      codes.uniq!
      codes
    end

    private def self.rank(caption : Metadata, names : Array(String)) : Tuple(Int32, Int32)
      pref_rank = names.size
      names.each_with_index do |name, index|
        if name_matches?(caption, name)
          pref_rank = index
          break
        end
      end

      auto_rank = caption.auto_generated ? 1 : 0
      {pref_rank, auto_rank}
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
      "Filipino (auto-generated)",
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
