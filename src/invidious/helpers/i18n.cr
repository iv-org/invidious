def load_locale(name)
  return JSON.parse(File.read("locales/#{name}.json")).as_h
end

def translate(locale : Hash(String, JSON::Any) | Nil, translation : String, text : String | Nil = nil)
  # if !locale[translation]?
  #   puts "Could not find translation for #{translation}"
  # end

  if locale && locale[translation]? && !locale[translation].as_s.empty?
    translation = locale[translation].as_s
  end

  if text
    translation = translation.gsub("`x`", text)
  end

  return translation
end
