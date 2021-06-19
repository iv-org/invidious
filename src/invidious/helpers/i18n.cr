LOCALES = {
  "ar"    => load_locale("ar"),
  "de"    => load_locale("de"),
  "el"    => load_locale("el"),
  "en-US" => load_locale("en-US"),
  "eo"    => load_locale("eo"),
  "es"    => load_locale("es"),
  "fa"    => load_locale("fa"),
  "fi"    => load_locale("fi"),
  "fr"    => load_locale("fr"),
  "he"    => load_locale("he"),
  "hr"    => load_locale("hr"),
  "id"    => load_locale("id"),
  "is"    => load_locale("is"),
  "it"    => load_locale("it"),
  "ja"    => load_locale("ja"),
  "nb-NO" => load_locale("nb-NO"),
  "nl"    => load_locale("nl"),
  "pl"    => load_locale("pl"),
  "pt-BR" => load_locale("pt-BR"),
  "pt-PT" => load_locale("pt-PT"),
  "ro"    => load_locale("ro"),
  "ru"    => load_locale("ru"),
  "sv-SE" => load_locale("sv-SE"),
  "tr"    => load_locale("tr"),
  "uk"    => load_locale("uk"),
  "zh-CN" => load_locale("zh-CN"),
  "zh-TW" => load_locale("zh-TW"),
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
