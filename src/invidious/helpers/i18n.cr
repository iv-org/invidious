LOCALES = {
  "ar"      => load_locale("ar"),      # Arabic
  "bn_BD"   => load_locale("bn_BD"),   # Bengali (Bangladesh)
  "cs"      => load_locale("cs"),      # Czech
  "da"      => load_locale("da"),      # Danish
  "de"      => load_locale("de"),      # German
  "el"      => load_locale("el"),      # Greek
  "en-US"   => load_locale("en-US"),   # English (US)
  "eo"      => load_locale("eo"),      # Esperanto
  "es"      => load_locale("es"),      # Spanish
  "eu"      => load_locale("eu"),      # Basque
  "fa"      => load_locale("fa"),      # Persian
  "fi"      => load_locale("fi"),      # Finnish
  "fr"      => load_locale("fr"),      # French
  "he"      => load_locale("he"),      # Hebrew
  "hr"      => load_locale("hr"),      # Croatian
  "hu-HU"   => load_locale("hu-HU"),   # Hungarian
  "id"      => load_locale("id"),      # Indonesian
  "is"      => load_locale("is"),      # Icelandic
  "it"      => load_locale("it"),      # Italian
  "ja"      => load_locale("ja"),      # Japanese
  "lt"      => load_locale("lt"),      # Lithuanian
  "nb-NO"   => load_locale("nb-NO"),   # Norwegian Bokmål
  "nl"      => load_locale("nl"),      # Dutch
  "pl"      => load_locale("pl"),      # Polish
  "pt-BR"   => load_locale("pt-BR"),   # Portuguese (Brazil)
  "pt-PT"   => load_locale("pt-PT"),   # Portuguese (Portugal)
  "ro"      => load_locale("ro"),      # Romanian
  "ru"      => load_locale("ru"),      # Russian
  "si"      => load_locale("si"),      # Sinhala
  "sk"      => load_locale("sk"),      # Slovak
  "sr"      => load_locale("sr"),      # Serbian
  "sr_Cyrl" => load_locale("sr_Cyrl"), # Serbian (cyrillic)
  "sv-SE"   => load_locale("sv-SE"),   # Swedish
  "tr"      => load_locale("tr"),      # Turkish
  "uk"      => load_locale("uk"),      # Ukrainian
  "vi"      => load_locale("vi"),      # Vietnamese
  "zh-CN"   => load_locale("zh-CN"),   # Chinese (Simplified)
  "zh-TW"   => load_locale("zh-TW"),   # Chinese (Traditional)
}

def load_locale(name)
  return JSON.parse(File.read("locales/#{name}.json")).as_h
end

def translate(locale : Hash(String, JSON::Any) | Nil, translation : String, text : String | Nil = nil)
  # if locale && !locale[translation]?
  #   puts "Could not find translation for #{translation.dump}"
  # end

  if locale && locale[translation]?
    case locale[translation]
    when .as_h?
      match_length = 0

      locale[translation].as_h.each do |key, value|
        if md = text.try &.match(/#{key}/)
          if md[0].size >= match_length
            translation = value.as_s
            match_length = md[0].size
          end
        end
      end
    when .as_s?
      if !locale[translation].as_s.empty?
        translation = locale[translation].as_s
      end
    else
      raise "Invalid translation #{translation}"
    end
  end

  if text
    translation = translation.gsub("`x`", text)
  end

  return translation
end

def translate_bool(locale : Hash(String, JSON::Any) | Nil, translation : Bool)
  case translation
  when true
    return translate(locale, "Yes")
  when false
    return translate(locale, "No")
  end
end
