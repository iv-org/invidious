require "json"

module Invidious::Videos
  struct Caption
    property name : String
    property language_code : String
    property base_url : String

    def initialize(@name, @language_code, @base_url)
    end

    # Parse the JSON structure from Youtube
    def self.from_yt_json(container : JSON::Any) : Array(Caption)
      caption_tracks = container
        .dig?("playerCaptionsTracklistRenderer", "captionTracks")
        .try &.as_a

      captions_list = [] of Caption
      return captions_list if caption_tracks.nil?

      caption_tracks.each do |caption|
        name = caption["name"]["simpleText"]? || caption["name"]["runs"][0]["text"]
        name = name.to_s.split(" - ")[0]

        language_code = caption["languageCode"].to_s
        base_url = caption["baseUrl"].to_s

        captions_list << Caption.new(name, language_code, base_url)
      end

      return captions_list
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
