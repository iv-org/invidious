require "spectator"
require "../src/invidious/helpers/i18next.cr"

Spectator.configure do |config|
  config.fail_blank
  config.randomize
end

def resolver
  I18next::Plurals::RESOLVER
end

FORM_TESTS = {
  "ach"   => I18next::Plurals::PluralForms::Single_gt_one,
  "ar"    => I18next::Plurals::PluralForms::Special_Arabic,
  "be"    => I18next::Plurals::PluralForms::Dual_Slavic,
  "cy"    => I18next::Plurals::PluralForms::Special_Welsh,
  "en"    => I18next::Plurals::PluralForms::Single_not_one,
  "fr"    => I18next::Plurals::PluralForms::Single_gt_one,
  "ga"    => I18next::Plurals::PluralForms::Special_Irish,
  "gd"    => I18next::Plurals::PluralForms::Special_Scottish_Gaelic,
  "he"    => I18next::Plurals::PluralForms::Special_Hebrew,
  "is"    => I18next::Plurals::PluralForms::Special_Icelandic,
  "jv"    => I18next::Plurals::PluralForms::Special_Javanese,
  "kw"    => I18next::Plurals::PluralForms::Special_Cornish,
  "lt"    => I18next::Plurals::PluralForms::Special_Lithuanian,
  "lv"    => I18next::Plurals::PluralForms::Special_Latvian,
  "mk"    => I18next::Plurals::PluralForms::Special_Macedonian,
  "mnk"   => I18next::Plurals::PluralForms::Special_Mandinka,
  "mt"    => I18next::Plurals::PluralForms::Special_Maltese,
  "or"    => I18next::Plurals::PluralForms::Special_Odia,
  "pl"    => I18next::Plurals::PluralForms::Special_Polish_Kashubian,
  "pt"    => I18next::Plurals::PluralForms::Single_gt_one,
  "pt-PT" => I18next::Plurals::PluralForms::Single_not_one,
  "pt-BR" => I18next::Plurals::PluralForms::Single_gt_one,
  "ro"    => I18next::Plurals::PluralForms::Special_Romanian,
  "su"    => I18next::Plurals::PluralForms::None,
  "sk"    => I18next::Plurals::PluralForms::Special_Czech_Slovak,
  "sl"    => I18next::Plurals::PluralForms::Special_Slovenian,
}

SUFFIX_TESTS = {
  "ach" => [
    {num: 0, suffix: ""},
    {num: 1, suffix: ""},
    {num: 10, suffix: "_plural"},
  ],
  "ar" => [
    {num: 0, suffix: "_0"},
    {num: 1, suffix: "_1"},
    {num: 2, suffix: "_2"},
    {num: 3, suffix: "_3"},
    {num: 4, suffix: "_3"},
    {num: 104, suffix: "_3"},
    {num: 11, suffix: "_4"},
    {num: 99, suffix: "_4"},
    {num: 199, suffix: "_4"},
    {num: 100, suffix: "_5"},
  ],
  "be" => [
    {num: 0, suffix: "_2"},
    {num: 1, suffix: "_0"},
    {num: 5, suffix: "_2"},
  ],
  "cy" => [
    {num: 0, suffix: "_2"},
    {num: 1, suffix: "_0"},
    {num: 3, suffix: "_2"},
    {num: 8, suffix: "_3"},
  ],
  "en" => [
    {num: 0, suffix: "_plural"},
    {num: 1, suffix: ""},
    {num: 10, suffix: "_plural"},
  ],
  "fr" => [
    {num: 0, suffix: ""},
    {num: 1, suffix: ""},
    {num: 10, suffix: "_plural"},
  ],
  "ga" => [
    {num: 1, suffix: "_0"},
    {num: 2, suffix: "_1"},
    {num: 3, suffix: "_2"},
    {num: 7, suffix: "_3"},
    {num: 11, suffix: "_4"},
  ],
  "gd" => [
    {num: 1, suffix: "_0"},
    {num: 2, suffix: "_1"},
    {num: 3, suffix: "_2"},
    {num: 20, suffix: "_3"},
  ],
  "he" => [
    {num: 0, suffix: "_3"},
    {num: 1, suffix: "_0"},
    {num: 2, suffix: "_1"},
    {num: 3, suffix: "_3"},
    {num: 20, suffix: "_2"},
    {num: 21, suffix: "_3"},
    {num: 30, suffix: "_2"},
    {num: 100, suffix: "_2"},
    {num: 101, suffix: "_3"},
  ],
  "is" => [
    {num: 1, suffix: ""},
    {num: 2, suffix: "_plural"},
  ],
  "jv" => [
    {num: 0, suffix: "_0"},
    {num: 1, suffix: "_1"},
  ],
  "kw" => [
    {num: 1, suffix: "_0"},
    {num: 2, suffix: "_1"},
    {num: 3, suffix: "_2"},
    {num: 4, suffix: "_3"},
  ],
  "lt" => [
    {num: 1, suffix: "_0"},
    {num: 2, suffix: "_1"},
    {num: 10, suffix: "_2"},
  ],
  "lv" => [
    {num: 1, suffix: "_0"},
    {num: 2, suffix: "_1"},
    {num: 0, suffix: "_2"},
  ],
  "mk" => [
    {num: 1, suffix: ""},
    {num: 2, suffix: "_plural"},
    {num: 0, suffix: "_plural"},
    {num: 11, suffix: "_plural"},
    {num: 21, suffix: ""},
    {num: 31, suffix: ""},
    {num: 311, suffix: "_plural"},
  ],
  "mnk" => [
    {num: 0, suffix: "_0"},
    {num: 1, suffix: "_1"},
    {num: 2, suffix: "_2"},
  ],
  "mt" => [
    {num: 1, suffix: "_0"},
    {num: 2, suffix: "_1"},
    {num: 11, suffix: "_2"},
    {num: 20, suffix: "_3"},
  ],
  "or" => [
    {num: 2, suffix: "_1"},
    {num: 1, suffix: "_0"},
  ],
  "pl" => [
    {num: 0, suffix: "_2"},
    {num: 1, suffix: "_0"},
    {num: 5, suffix: "_2"},
  ],
  "pt" => [
    {num: 0, suffix: ""},
    {num: 1, suffix: ""},
    {num: 10, suffix: "_plural"},
  ],
  "pt-PT" => [
    {num: 0, suffix: "_plural"},
    {num: 1, suffix: ""},
    {num: 10, suffix: "_plural"},
  ],
  "pt-BR" => [
    {num: 0, suffix: ""},
    {num: 1, suffix: ""},
    {num: 10, suffix: "_plural"},
  ],
  "ro" => [
    {num: 0, suffix: "_1"},
    {num: 1, suffix: "_0"},
    {num: 20, suffix: "_2"},
  ],
  "su" => [
    {num: 0, suffix: "_0"},
    {num: 1, suffix: "_0"},
    {num: 10, suffix: "_0"},
  ],
  "sk" => [
    {num: 0, suffix: "_2"},
    {num: 1, suffix: "_0"},
    {num: 5, suffix: "_2"},
  ],
  "sl" => [
    {num: 5, suffix: "_0"},
    {num: 1, suffix: "_1"},
    {num: 2, suffix: "_2"},
    {num: 3, suffix: "_3"},
  ],
}

Spectator.describe "i18next_Plural_Resolver" do
  describe "get_plural_form" do
    sample FORM_TESTS do |locale, form|
      it "returns the right plural form for locale '#{locale}'" do
        expect(resolver.get_plural_form(locale)).to eq(form)
      end
    end
  end

  describe "get_suffix" do
    sample SUFFIX_TESTS do |locale, tests|
      it "returns the right suffix for locale '#{locale}'" do
        tests.each do |d|
          expect(resolver.get_suffix(locale, d[:num])).to eq(d[:suffix])
        end
      end
    end
  end
end
