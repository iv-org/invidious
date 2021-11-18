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
end
