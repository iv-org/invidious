# SPDX-FileCopyrightText: 2019 Omar Roth <omarroth@protonmail.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

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
