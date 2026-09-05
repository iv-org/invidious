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
    # ranked by preference slot, then human tracks before auto-generated,
    # then more-specific language matches ahead of base-language fallbacks.
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

    # Common LANGUAGES names mapped to ISO 639-1 / BCP-47 codes.
    # Auto-generated suffixes are stripped before lookup; regional
    # qualifiers keep their more specific code and fall back to the base.
    NAME_TO_CODE = {
      "arabic"                   => "ar",
      "chinese"                  => "zh",
      "chinese (china)"          => "zh-cn",
      "chinese (hong kong)"      => "zh-hk",
      "chinese (simplified)"     => "zh-hans",
      "chinese (taiwan)"         => "zh-tw",
      "chinese (traditional)"    => "zh-hant",
      "dutch"                    => "nl",
      "english"                  => "en",
      "english (united kingdom)" => "en-gb",
      "english (united states)"  => "en-us",
      "filipino"                 => "fil",
      "french"                   => "fr",
      "german"                   => "de",
      "indonesian"               => "id",
      "italian"                  => "it",
      "japanese"                 => "ja",
      "korean"                   => "ko",
      "portuguese"               => "pt",
      "portuguese (brazil)"      => "pt-br",
      "russian"                  => "ru",
      "spanish"                  => "es",
      "spanish (latin america)"  => "es-419",
      "spanish (mexico)"         => "es-mx",
      "spanish (spain)"          => "es-es",
      "turkish"                  => "tr",
      "vietnamese"               => "vi",
    }

    private def self.name_matches?(caption : Metadata, name : String) : Bool
      !match_index(caption, name).nil?
    end

    # Tokens from most specific to least: "English (United States)" ->
    # "english (united states)", "en-us", "english", "en".
    private def self.match_tokens(name : String) : Array(String)
      token = name.strip.downcase
      return [] of String if token.empty?

      lookup = token
      if lookup.ends_with?(" (auto-generated)")
        lookup = lookup.rchop(" (auto-generated)")
      end

      tokens = [lookup]
      if mapped = NAME_TO_CODE[lookup]?
        tokens << mapped
      end

      base_name = lookup.split(" - ")[0].split(" (")[0].strip
      if !base_name.empty? && base_name != lookup
        tokens << base_name
        if mapped = NAME_TO_CODE[base_name]?
          tokens << mapped
        end
      end

      if lookup.includes?("-")
        tokens << lookup.split("-", 2)[0]
      elsif lookup.size.in?(2..3) && lookup.chars.all?(&.ascii_letter?)
        tokens << lookup
      end

      tokens.uniq
    end

    private def self.match_index(caption : Metadata, name : String) : Int32?
      needles = match_tokens(name)
      return nil if needles.empty?

      caption_name = caption.name.strip.downcase
      lang = caption.language_code.strip.downcase
      base_lang = lang.split("-", 2)[0]
      caption_tokens = match_tokens(caption.name)
      caption_tokens << lang
      caption_tokens << base_lang

      needles.each_with_index do |needle, index|
        if caption_name == needle ||
           caption_name.starts_with?(needle + " (") ||
           caption_name.starts_with?(needle + " - ") ||
           lang == needle ||
           (base_lang == needle && !needle.includes?("-")) ||
           caption_tokens.includes?(needle)
          return index
        end
      end

      nil
    end

    private def self.rank(caption : Metadata, names : Array(String)) : Tuple(Int32, Int32, Int32)
      pref_rank = names.size
      specificity = Int32::MAX
      names.each_with_index do |name, index|
        if found = match_index(caption, name)
          pref_rank = index
          specificity = found
          break
        end
      end

      auto_rank = caption.auto_generated ? 1 : 0
      {pref_rank, auto_rank, specificity}
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
