require "json"
require "../src/invidious/helpers/i18n.cr"

def locale_to_array(locale_name)
  arrayifed_locale_data = [] of Tuple(String, JSON::Any | String)
  keys_only_array = [] of String
  LOCALES[locale_name].each do |k, v|
    if v.as_h?
      arrayifed_locale_data << {k, JSON.parse(v.as_h.to_json)}
    elsif v.as_s?
      arrayifed_locale_data << {k, v.as_s}
    end

    keys_only_array << k
  end

  return arrayifed_locale_data, keys_only_array
end

# Invidious currently has some unloaded localization files. We shouldn't need to propagate new keys onto those.
# We'll also remove the reference locale (english) from the list to process.
loaded_locales = LOCALES.keys.select! { |key| key != "en-US" }
english_locale, english_locale_keys = locale_to_array("en-US")

# In order to automatically propagate locale keys we're going to be needing two arrays.
# One is an array containing each locale data encoded as tuples. The other would contain
# sets of only the keys of each locale files.
#
# The second array is to make sure that an key from the english reference file is present
# in whatever the current locale we're scanning is.
locale_list = [] of Array(Tuple(String, JSON::Any | String))
locale_list_with_only_keys = [] of Array(String)

# Populates the created arrays from above
loaded_locales.each do |name|
  arrayifed_locale_data, keys_only_locale = locale_to_array(name)

  locale_list << arrayifed_locale_data
  locale_list_with_only_keys << keys_only_locale
end

# Propagate additions
locale_list_with_only_keys.dup.each_with_index do |keys_of_locale_in_processing, index_of_locale_in_processing|
  insert_at = {} of Int32 => Tuple(String, JSON::Any | String)

  LOCALES["en-US"].each_with_index do |ref_locale_data, ref_locale_key_index|
    ref_locale_key, ref_locale_value = ref_locale_data

    # Found an new key that isn't present in the current locale..
    if !keys_of_locale_in_processing.includes? ref_locale_key
      # In terms of structure there's currently only two types; one for plural and the other for singular translations.
      if ref_locale_value.as_h?
        insert_at[ref_locale_key_index] = {ref_locale_key, JSON.parse({"([^.,0-9]|^)1([^.,0-9]|$)" => "", "" => ""}.to_json)}
      else
        insert_at[ref_locale_key_index] = {ref_locale_key, ""}
      end
    end
  end

  insert_at.each do |location_to_insert, data|
    locale_list_with_only_keys[index_of_locale_in_processing].insert(location_to_insert, data[0])
    locale_list[index_of_locale_in_processing].insert(location_to_insert, data)
  end
end

# Propagate removals
locale_list_with_only_keys.dup.each_with_index do |keys_of_locale_in_processing, index_of_locale_in_processing|
  remove_at = [] of Int32

  keys_of_locale_in_processing.each_with_index do |current_key, current_key_index|
    if !english_locale_keys.includes? current_key
      remove_at << current_key_index
    end
  end

  remove_at.each do |index_to_remove_at|
    locale_list_with_only_keys[index_of_locale_in_processing].delete_at(index_to_remove_at)
    locale_list[index_of_locale_in_processing].delete_at(index_to_remove_at)
  end
end

# Now we convert back to our original format.
final_locale_list = [] of String
locale_list.each do |locale|
  intermediate_hash = {} of String => (JSON::Any | String)
  locale.each { |k, v| intermediate_hash[k] = v }
  final_locale_list << intermediate_hash.to_pretty_json(indent = "    ")
end

locale_map = Hash.zip(loaded_locales, final_locale_list)

# Export
locale_map.each do |locale_name, locale_contents|
  File.write("locales/#{locale_name}.json", "#{locale_contents}\n")
end
