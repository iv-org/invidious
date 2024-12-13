require "../../../src/invidious/search/filters"

require "http/params"
require "spectator"

Spectator.configure do |config|
  config.fail_blank
  config.randomize
end

# Encoded filter values are extracted from the search
# page of Youtube with any browser devtools HTML inspector.

DATE_FILTERS = {
  Invidious::Search::Filters::Date::Hour  => "EgIIAfABAQ%3D%3D",
  Invidious::Search::Filters::Date::Today => "EgIIAvABAQ%3D%3D",
  Invidious::Search::Filters::Date::Week  => "EgIIA_ABAQ%3D%3D",
  Invidious::Search::Filters::Date::Month => "EgIIBPABAQ%3D%3D",
  Invidious::Search::Filters::Date::Year  => "EgIIBfABAQ%3D%3D",
}

TYPE_FILTERS = {
  Invidious::Search::Filters::Type::Video    => "EgIQAfABAQ%3D%3D",
  Invidious::Search::Filters::Type::Channel  => "EgIQAvABAQ%3D%3D",
  Invidious::Search::Filters::Type::Playlist => "EgIQA_ABAQ%3D%3D",
  Invidious::Search::Filters::Type::Movie    => "EgIQBPABAQ%3D%3D",
}

DURATION_FILTERS = {
  Invidious::Search::Filters::Duration::Short  => "EgIYAfABAQ%3D%3D",
  Invidious::Search::Filters::Duration::Medium => "EgIYA_ABAQ%3D%3D",
  Invidious::Search::Filters::Duration::Long   => "EgIYAvABAQ%3D%3D",
}

FEATURE_FILTERS = {
  Invidious::Search::Filters::Features::Live       => "EgJAAfABAQ%3D%3D",
  Invidious::Search::Filters::Features::FourK      => "EgJwAfABAQ%3D%3D",
  Invidious::Search::Filters::Features::HD         => "EgIgAfABAQ%3D%3D",
  Invidious::Search::Filters::Features::Subtitles  => "EgIoAfABAQ%3D%3D",
  Invidious::Search::Filters::Features::CCommons   => "EgIwAfABAQ%3D%3D",
  Invidious::Search::Filters::Features::ThreeSixty => "EgJ4AfABAQ%3D%3D",
  Invidious::Search::Filters::Features::VR180      => "EgPQAQHwAQE%3D",
  Invidious::Search::Filters::Features::ThreeD     => "EgI4AfABAQ%3D%3D",
  Invidious::Search::Filters::Features::HDR        => "EgPIAQHwAQE%3D",
  Invidious::Search::Filters::Features::Location   => "EgO4AQHwAQE%3D",
  Invidious::Search::Filters::Features::Purchased  => "EgJIAfABAQ%3D%3D",
}

SORT_FILTERS = {
  Invidious::Search::Filters::Sort::Relevance => "8AEB",
  Invidious::Search::Filters::Sort::Date      => "CALwAQE%3D",
  Invidious::Search::Filters::Sort::Views     => "CAPwAQE%3D",
  Invidious::Search::Filters::Sort::Rating    => "CAHwAQE%3D",
}

Spectator.describe Invidious::Search::Filters do
  # -------------------
  #  Encode YT params
  # -------------------

  describe "#to_yt_params" do
    sample DATE_FILTERS do |value, result|
      it "Encodes upload date filter '#{value}'" do
        expect(described_class.new(date: value).to_yt_params).to eq(result)
      end
    end

    sample TYPE_FILTERS do |value, result|
      it "Encodes content type filter '#{value}'" do
        expect(described_class.new(type: value).to_yt_params).to eq(result)
      end
    end

    sample DURATION_FILTERS do |value, result|
      it "Encodes duration filter '#{value}'" do
        expect(described_class.new(duration: value).to_yt_params).to eq(result)
      end
    end

    sample FEATURE_FILTERS do |value, result|
      it "Encodes feature filter '#{value}'" do
        expect(described_class.new(features: value).to_yt_params).to eq(result)
      end
    end

    sample SORT_FILTERS do |value, result|
      it "Encodes sort filter '#{value}'" do
        expect(described_class.new(sort: value).to_yt_params).to eq(result)
      end
    end
  end

  # -------------------
  #  Decode YT params
  # -------------------

  describe "#from_yt_params" do
    sample DATE_FILTERS do |value, encoded|
      it "Decodes upload date filter '#{value}'" do
        params = HTTP::Params.parse("sp=#{encoded}")

        expect(described_class.from_yt_params(params))
          .to eq(described_class.new(date: value))
      end
    end

    sample TYPE_FILTERS do |value, encoded|
      it "Decodes content type filter '#{value}'" do
        params = HTTP::Params.parse("sp=#{encoded}")

        expect(described_class.from_yt_params(params))
          .to eq(described_class.new(type: value))
      end
    end

    sample DURATION_FILTERS do |value, encoded|
      it "Decodes duration filter '#{value}'" do
        params = HTTP::Params.parse("sp=#{encoded}")

        expect(described_class.from_yt_params(params))
          .to eq(described_class.new(duration: value))
      end
    end

    sample FEATURE_FILTERS do |value, encoded|
      it "Decodes feature filter '#{value}'" do
        params = HTTP::Params.parse("sp=#{encoded}")

        expect(described_class.from_yt_params(params))
          .to eq(described_class.new(features: value))
      end
    end

    sample SORT_FILTERS do |value, encoded|
      it "Decodes sort filter '#{value}'" do
        params = HTTP::Params.parse("sp=#{encoded}")

        expect(described_class.from_yt_params(params))
          .to eq(described_class.new(sort: value))
      end
    end
  end
end
