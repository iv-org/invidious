# I18next-compatible implementation of plural forms
#
module I18next::Plurals
  # -----------------------------------
  #  I18next plural forms definition
  # -----------------------------------

  enum PluralForms
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
    Special_Odia             = 23
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
    "or"  => PluralForms::Special_Odia,
    "pl"  => PluralForms::Special_Polish_Kashubian,
    "ro"  => PluralForms::Special_Romanian,
    "sk"  => PluralForms::Special_Czech_Slovak,
    "sl"  => PluralForms::Special_Slovenian,
  }

  # These are the v1 and v2 compatible suffixes.
  # The array indices matches the PluralForms enum above.
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
    [2, 1],                # 23 (Odia)
  ]

  # -----------------------------------
  #  I18next plural resolver class
  # -----------------------------------

  RESOLVER = Resolver.new

  class Resolver
    private property forms = {} of String => PluralForms
    property version : UInt8 = 3

    # Options
    property simplify_plural_suffix : Bool = true

    def initialize(version : Int = 3)
      # Sanity checks
      # V4 isn't supported, as it requires a full CLDR database.
      if version > 4 || version == 0
        raise "Invalid i18next version: v#{version}."
      elsif version == 4
        # Logger.error("Unsupported i18next version: v4. Falling back to v3")
        @version = 3_u8
      else
        @version = version.to_u8
      end

      self.init_rules
    end

    def init_rules
      # Look into sets
      PLURAL_SETS.each do |form, langs|
        langs.each { |lang| self.forms[lang] = form }
      end

      # Add plurals from the "singles" set
      self.forms.merge!(PLURAL_SINGLES)
    end

    def get_plural_form(locale : String) : PluralForms
      # Extract the ISO 639-1 or 639-2 code from an RFC 5646 language code,
      # except for pt-BR and pt-PT which needs to be kept as-is.
      if !locale.matches?(/^pt-(BR|PT)$/)
        locale = locale.split('-')[0]
      end

      return self.forms[locale] if self.forms[locale]?

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

    # Emulate the `rule.numbers.size == 2 && rule.numbers[0] == 1` check
    # from original i18next code
    private def is_simple_plural(form : PluralForms) : Bool
      case form
      when .single_gt_one?      then return true
      when .single_not_one?     then return true
      when .special_icelandic?  then return true
      when .special_macedonian? then return true
      else
        return false
      end
    end

    private def get_suffix_retrocompat(locale : String, count : Int) : String
      # Get plural form
      plural_form = get_plural_form(locale)

      # Languages with no plural have the "_0" suffix
      return "_0" if plural_form.none?

      # Get the index and suffix for this number
      idx = SuffixIndex.get_index(plural_form, count)

      # Simple plurals are handled differently in all versions (but v4)
      if @simplify_plural_suffix && is_simple_plural(plural_form)
        return (idx == 1) ? "_plural" : ""
      end

      # More complex plurals
      # TODO: support v1 and v2
      # TODO: support `options.prepend` (v2 and v3)
      # this.options.prepend && suffix.toString() ? this.options.prepend + suffix.toString() : suffix.toString()
      #
      # case @version
      # when 1
      #   suffix = SUFFIXES_V1_V2[plural_form.to_i][idx]
      #   return (suffix == 1) ? "" : return "_plural_#{suffix}"
      # when 2
      #   return "_#{suffix}"
      # else # v3
      return "_#{idx}"
      # end
    end
  end

  # -----------------------------
  #  Plural functions
  # -----------------------------

  module SuffixIndex
    def self.get_index(plural_form : PluralForms, count : Int) : UInt8
      case plural_form
      when .single_gt_one?            then return (count > 1) ? 1_u8 : 0_u8
      when .single_not_one?           then return (count != 1) ? 1_u8 : 0_u8
      when .none?                     then return 0_u8
      when .dual_slavic?              then return dual_slavic(count)
      when .special_arabic?           then return special_arabic(count)
      when .special_czech_slovak?     then return special_czech_slovak(count)
      when .special_polish_kashubian? then return special_polish_kashubian(count)
      when .special_welsh?            then return special_welsh(count)
      when .special_irish?            then return special_irish(count)
      when .special_scottish_gaelic?  then return special_scottish_gaelic(count)
      when .special_icelandic?        then return special_icelandic(count)
      when .special_javanese?         then return special_javanese(count)
      when .special_cornish?          then return special_cornish(count)
      when .special_lithuanian?       then return special_lithuanian(count)
      when .special_latvian?          then return special_latvian(count)
      when .special_macedonian?       then return special_macedonian(count)
      when .special_mandinka?         then return special_mandinka(count)
      when .special_maltese?          then return special_maltese(count)
      when .special_romanian?         then return special_romanian(count)
      when .special_slovenian?        then return special_slovenian(count)
      when .special_hebrew?           then return special_hebrew(count)
      when .special_odia?             then return special_odia(count)
      else
        # default, if nothing matched above
        return 0_u8
      end
    end

    # Plural form of Slavic languages (E.g: Russian)
    #
    # Corresponds to i18next rule #4
    # Rule: (n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)
    #
    def self.dual_slavic(count : Int) : UInt8
      n_mod_10 = count % 10
      n_mod_100 = count % 100

      if n_mod_10 == 1 && n_mod_100 != 11
        return 0_u8
      elsif n_mod_10 >= 2 && n_mod_10 <= 4 && (n_mod_100 < 10 || n_mod_100 >= 20)
        return 1_u8
      else
        return 2_u8
      end
    end

    # Plural form for Arabic language
    #
    # Corresponds to i18next rule #5
    # Rule: (n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5)
    #
    def self.special_arabic(count : Int) : UInt8
      return count.to_u8 if (count == 0 || count == 1 || count == 2)

      n_mod_100 = count % 100

      return 3_u8 if (n_mod_100 >= 3 && n_mod_100 <= 10)
      return 4_u8 if (n_mod_100 >= 11)
      return 5_u8
    end

    # Plural form for Czech and Slovak languages
    #
    # Corresponds to i18next rule #6
    # Rule: ((n==1) ? 0 : (n>=2 && n<=4) ? 1 : 2)
    #
    def self.special_czech_slovak(count : Int) : UInt8
      return 0_u8 if (count == 1)
      return 1_u8 if (count >= 2 && count <= 4)
      return 2_u8
    end

    # Plural form for Polish and Kashubian languages
    #
    # Corresponds to i18next rule #7
    # Rule: (n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)
    #
    def self.special_polish_kashubian(count : Int) : UInt8
      return 0_u8 if (count == 1)

      n_mod_10 = count % 10
      n_mod_100 = count % 100

      if n_mod_10 >= 2 && n_mod_10 <= 4 && (n_mod_100 < 10 || n_mod_100 >= 20)
        return 1_u8
      else
        return 2_u8
      end
    end

    # Plural form for Welsh language
    #
    # Corresponds to i18next rule #8
    # Rule: ((n==1) ? 0 : (n==2) ? 1 : (n != 8 && n != 11) ? 2 : 3)
    #
    def self.special_welsh(count : Int) : UInt8
      return 0_u8 if (count == 1)
      return 1_u8 if (count == 2)
      return 2_u8 if (count != 8 && count != 11)
      return 3_u8
    end

    # Plural form for Irish language
    #
    # Corresponds to i18next rule #10
    # Rule: (n==1 ? 0 : n==2 ? 1 : n<7 ? 2 : n<11 ? 3 : 4)
    #
    def self.special_irish(count : Int) : UInt8
      return 0_u8 if (count == 1)
      return 1_u8 if (count == 2)
      return 2_u8 if (count < 7)
      return 3_u8 if (count < 11)
      return 4_u8
    end

    # Plural form for Gaelic language
    #
    # Corresponds to i18next rule #11
    # Rule: ((n==1 || n==11) ? 0 : (n==2 || n==12) ? 1 : (n > 2 && n < 20) ? 2 : 3)
    #
    def self.special_scottish_gaelic(count : Int) : UInt8
      return 0_u8 if (count == 1 || count == 11)
      return 1_u8 if (count == 2 || count == 12)
      return 2_u8 if (count > 2 && count < 20)
      return 3_u8
    end

    # Plural form for Icelandic language
    #
    # Corresponds to i18next rule #12
    # Rule: (n%10!=1 || n%100==11)
    #
    def self.special_icelandic(count : Int) : UInt8
      if (count % 10) != 1 || (count % 100) == 11
        return 1_u8
      else
        return 0_u8
      end
    end

    # Plural form for Javanese language
    #
    # Corresponds to i18next rule #13
    # Rule: (n !== 0)
    #
    def self.special_javanese(count : Int) : UInt8
      return (count != 0) ? 1_u8 : 0_u8
    end

    # Plural form for Cornish language
    #
    # Corresponds to i18next rule #14
    # Rule: ((n==1) ? 0 : (n==2) ? 1 : (n == 3) ? 2 : 3)
    #
    def self.special_cornish(count : Int) : UInt8
      return 0_u8 if count == 1
      return 1_u8 if count == 2
      return 2_u8 if count == 3
      return 3_u8
    end

    # Plural form for Lithuanian language
    #
    # Corresponds to i18next rule #15
    # Rule: (n%10==1 && n%100!=11 ? 0 : n%10>=2 && (n%100<10 || n%100>=20) ? 1 : 2)
    #
    def self.special_lithuanian(count : Int) : UInt8
      n_mod_10 = count % 10
      n_mod_100 = count % 100

      if n_mod_10 == 1 && n_mod_100 != 11
        return 0_u8
      elsif n_mod_10 >= 2 && (n_mod_100 < 10 || n_mod_100 >= 20)
        return 1_u8
      else
        return 2_u8
      end
    end

    # Plural form for Latvian language
    #
    # Corresponds to i18next rule #16
    # Rule: (n%10==1 && n%100!=11 ? 0 : n !== 0 ? 1 : 2)
    #
    def self.special_latvian(count : Int) : UInt8
      if (count % 10) == 1 && (count % 100) != 11
        return 0_u8
      elsif count != 0
        return 1_u8
      else
        return 2_u8
      end
    end

    # Plural form for Macedonian language
    #
    # Corresponds to i18next rule #17
    # Rule: (n==1 || n%10==1 && n%100!=11 ? 0 : 1)
    #
    def self.special_macedonian(count : Int) : UInt8
      if count == 1 || ((count % 10) == 1 && (count % 100) != 11)
        return 0_u8
      else
        return 1_u8
      end
    end

    # Plural form for Mandinka language
    #
    # Corresponds to i18next rule #18
    # Rule: (n==0 ? 0 : n==1 ? 1 : 2)
    #
    def self.special_mandinka(count : Int) : UInt8
      return (count == 0 || count == 1) ? count.to_u8 : 2_u8
    end

    # Plural form for Maltese language
    #
    # Corresponds to i18next rule #19
    # Rule: (n==1 ? 0 : n==0 || ( n%100>1 && n%100<11) ? 1 : (n%100>10 && n%100<20 ) ? 2 : 3)
    #
    def self.special_maltese(count : Int) : UInt8
      return 0_u8 if count == 1
      return 1_u8 if count == 0

      n_mod_100 = count % 100
      return 1_u8 if (n_mod_100 > 1 && n_mod_100 < 11)
      return 2_u8 if (n_mod_100 > 10 && n_mod_100 < 20)
      return 3_u8
    end

    # Plural form for Romanian language
    #
    # Corresponds to i18next rule #20
    # Rule: (n==1 ? 0 : (n==0 || (n%100 > 0 && n%100 < 20)) ? 1 : 2)
    #
    def self.special_romanian(count : Int) : UInt8
      return 0_u8 if count == 1
      return 1_u8 if count == 0

      n_mod_100 = count % 100
      return 1_u8 if (n_mod_100 > 0 && n_mod_100 < 20)
      return 2_u8
    end

    # Plural form for Slovenian language
    #
    # Corresponds to i18next rule #21
    # Rule: (n%100==1 ? 1 : n%100==2 ? 2 : n%100==3 || n%100==4 ? 3 : 0)
    #
    def self.special_slovenian(count : Int) : UInt8
      n_mod_100 = count % 100
      return 1_u8 if (n_mod_100 == 1)
      return 2_u8 if (n_mod_100 == 2)
      return 3_u8 if (n_mod_100 == 3 || n_mod_100 == 4)
      return 0_u8
    end

    # Plural form for Hebrew language
    #
    # Corresponds to i18next rule #22
    # Rule: (n==1 ? 0 : n==2 ? 1 : (n<0 || n>10) && n%10==0 ? 2 : 3)
    #
    def self.special_hebrew(count : Int) : UInt8
      return 0_u8 if (count == 1)
      return 1_u8 if (count == 2)

      if (count < 0 || count > 10) && (count % 10) == 0
        return 2_u8
      else
        return 3_u8
      end
    end

    # Plural form for Odia ("or") language
    #
    # This one is a bit special. It should use rule #2 (like english)
    # but the "numbers" (suffixes?) it has are inverted, so we'll make a
    # special rule for it.
    #
    def self.special_odia(count : Int) : UInt8
      return (count == 1) ? 0_u8 : 1_u8
    end
  end
end
