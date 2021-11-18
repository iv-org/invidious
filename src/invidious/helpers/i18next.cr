# I18next-compatible implementation of plural forms
#
module I18next::Plurals
  # -----------------------------------
  #  I18next plural forms definition
  # -----------------------------------

  private enum PluralForms
    # One singular, one plural forms
    Single_gt_one  = 1 # E.g: French
    Single_not_one = 2 # E.g: English

    # No plural forms (E.g: Azerbaijani)
    None = 3

    # One singular, two plural forms
    Dual_Slavic = 4 # E.g: Russian

    # Special cases (rules used by only one or two language(s))
    Special_Arabic           =  5
    Special_Czech_Slovak     =  6
    Special_Polish_Kashubian =  7
    Special_Welsh            =  8
    Special_Irish            = 10
    Special_Scottish_Gaelic  = 11
    Special_Icelandic        = 12
    Special_Javanese         = 13
    Special_Cornish          = 14
    Special_Lithuanian       = 15
    Special_Latvian          = 16
    Special_Macedonian       = 17
    Special_Mandinka         = 18
    Special_Maltese          = 19
    Special_Romanian         = 20
    Special_Slovenian        = 21
    Special_Hebrew           = 22
  end

  private PLURAL_SETS = {
    PluralForms::Single_gt_one => [
      "ach", "ak", "am", "arn", "br", "fil", "fr", "gun", "ln", "mfe", "mg",
      "mi", "oc", "pt", "pt-BR", "tg", "tl", "ti", "tr", "uz", "wa",
    ],
    PluralForms::Single_not_one => [
      "af", "an", "ast", "az", "bg", "bn", "ca", "da", "de", "dev", "el", "en",
      "eo", "es", "et", "eu", "fi", "fo", "fur", "fy", "gl", "gu", "ha", "hi",
      "hu", "hy", "ia", "it", "kk", "kn", "ku", "lb", "mai", "ml", "mn", "mr",
      "nah", "nap", "nb", "ne", "nl", "nn", "no", "nso", "pa", "pap", "pms",
      "ps", "pt-PT", "rm", "sco", "se", "si", "so", "son", "sq", "sv", "sw",
      "ta", "te", "tk", "ur", "yo",
    ],
    PluralForms::None => [
      "ay", "bo", "cgg", "fa", "ht", "id", "ja", "jbo", "ka", "km", "ko", "ky",
      "lo", "ms", "sah", "su", "th", "tt", "ug", "vi", "wo", "zh",
    ],
    PluralForms::Dual_Slavic => [
      "be", "bs", "cnr", "dz", "hr", "ru", "sr", "uk",
    ],
  }

  private PLURAL_SINGLES = {
    "ar"  => PluralForms::Special_Arabic,
    "cs"  => PluralForms::Special_Czech_Slovak,
    "csb" => PluralForms::Special_Polish_Kashubian,
    "cy"  => PluralForms::Special_Welsh,
    "ga"  => PluralForms::Special_Irish,
    "gd"  => PluralForms::Special_Scottish_Gaelic,
    "he"  => PluralForms::Special_Hebrew,
    "is"  => PluralForms::Special_Icelandic,
    "iw"  => PluralForms::Special_Hebrew,
    "jv"  => PluralForms::Special_Javanese,
    "kw"  => PluralForms::Special_Cornish,
    "lt"  => PluralForms::Special_Lithuanian,
    "lv"  => PluralForms::Special_Latvian,
    "mk"  => PluralForms::Special_Macedonian,
    "mnk" => PluralForms::Special_Mandinka,
    "mt"  => PluralForms::Special_Maltese,
    "pl"  => PluralForms::Special_Polish_Kashubian,
    "ro"  => PluralForms::Special_Romanian,
    "sk"  => PluralForms::Special_Czech_Slovak,
    "sl"  => PluralForms::Special_Slovenian,
  }

  # The array indices matches the PluralForms enum above
  private NUMBERS = [
    [1, 2],                # 1
    [1, 2],                # 2
    [1],                   # 3
    [1, 2, 5],             # 4
    [0, 1, 2, 3, 11, 100], # 5
    [1, 2, 5],             # 6
    [1, 2, 5],             # 7
    [1, 2, 3, 8],          # 8
    [1, 2],                # 9 (not used)
    [1, 2, 3, 7, 11],      # 10
    [1, 2, 3, 20],         # 11
    [1, 2],                # 12
    [0, 1],                # 13
    [1, 2, 3, 4],          # 14
    [1, 2, 10],            # 15
    [1, 2, 0],             # 16
    [1, 2],                # 17
    [0, 1, 2],             # 18
    [1, 2, 11, 20],        # 19
    [1, 2, 20],            # 20
    [5, 1, 2, 3],          # 21
    [1, 2, 20, 21],        # 22
  ]

  # "or" ()
  private NUMBERS_OR = [2, 1]

  # -----------------------------------
  #  I18next plural resolver class
  # -----------------------------------

  class Resolver
    @@forms : Hash(String, PluralForms) = init_rules()
    @@version : UInt8 = 3

    # Options
    property simplify_plural_suffix : Bool = true

    # Suffixes
    SUFFIXES_V1 = {
      "",
      "_plural_1",
      "_plural_2",
      "_plural_3",
      "_plural_11",
      "_plural_100",
    }
    SUFFIXES_V2 = {"_0", "_1", "_2", "_3", "_11", "_100"}
    SUFFIXES_V3 = {"_0", "_1", "_2", "_3", "_4", "_5"}

    def initialize(version : UInt8 = 3)
      # Sanity checks
      # V4 isn't supported, as it requires a full CLDR database.
      if version > 4 || version == 0
        raise "Invalid i18next version: v#{version}."
      elsif version == 4
        # Logger.error("Unsupported i18next version: v4. Falling back to v3")
        @@version = 3
      else
        @@version = version
      end
    end

    def self.init_rules
      # Look into sets
      PLURAL_SETS.each do |form, langs|
        langs.each { |lang| @@forms[lang] = form }
      end

      # Add plurals from the "singles" set
      @@forms.merge!(PLURAL_SINGLES)
    end

    def get_plural_form(locale : String) : PluralForms
      # Extract the ISO 639-1 or 639-2 code from an RFC 5646
      # language code, except for pt-BR which needs to be kept as-is.
      if locale.starts_with?("pt-BR")
        locale = "pt-BR"
      else
        locale = locale.split('-')[0]
      end

      return @@forms[locale] if @@forms[locale]?

      # If nothing was found, then use the most common form, i.e
      # one singular and one plural, as in english. Not perfect,
      # but better than yielding an exception at the user.
      return PluralForms::Single_not_one
    end

    def get_suffix(locale : String, count : Int) : String
      # Checked count must be absolute. In i18next, `rule.noAbs` is used to
      # determine if comparison should be done on a signed or unsigned integer,
      # but this variable is never set, resulting in the comparison always
      # being done on absolute numbers.
      return get_suffix_retrocompat(locale, count.abs)
    end

    def get_suffix_retrocompat(locale : String, count : Int) : String
      # Get plural form
      plural_form = get_plural_form(locale)
      rule_numbers = (locale == "or") ? NUMBERS_OR : NUMBERS[plural_form.to_i]

      # Languages with no plural have no suffix
      return "" if plural_form.none?

      # Get the index and suffix for this number
      # idx = Todo
      suffix = rule_numbers[idx]

      # Simple plurals are handled differently in all versions (but v4)
      if @simplify_plural_suffix && rule_numbers.size == 2 && rule_numbers[0] == 1
        return "_plural" if (suffix == 2)
        return "" if (suffix == 1)
      end

      # More complex plurals
      # TODO: support `options.prepend` for v2 and v3
      # this.options.prepend && suffix.toString() ? this.options.prepend + suffix.toString() : suffix.toString()
      case @version
      when 1 then return SUFFIXES_V1[idx]
      when 2 then return SUFFIXES_V2[idx]
      else        return SUFFIXES_V3[idx]
      end
    end
  end
end
