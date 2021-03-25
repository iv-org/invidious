require "spec"
require "json"
require "../src/invidious/helpers/i18n.cr"

describe "Locales" do
  describe "#consistency" do
    locales_list = LOCALES.keys.select! { |key| key != "en-US" }

    locales_list.each do |locale|
      puts "\nChecking locale #{locale}"
      failed = false

      # Use "en-US" as the reference
      LOCALES["en-US"].each_key do |ref_key|
        # Catch exception in order to give a hint on what caused
        # the failure, and test one locale completely before failing
        begin
          LOCALES[locale].has_key?(ref_key).should be_true
        rescue
          failed = true
          puts "  Missing key in locale #{locale}: '#{ref_key}'"
        end
      end

      # Throw failed assertion exception in here
      failed.should be_false
    end
  end
end
