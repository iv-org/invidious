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
  Invidious::Search::Filters::Date::Hour  => "EgIIAQ%3D%3D",
  Invidious::Search::Filters::Date::Today => "EgIIAg%3D%3D",
  Invidious::Search::Filters::Date::Week  => "EgIIAw%3D%3D",
  Invidious::Search::Filters::Date::Month => "EgIIBA%3D%3D",
  Invidious::Search::Filters::Date::Year  => "EgIIBQ%3D%3D",
}

TYPE_FILTERS = {
  Invidious::Search::Filters::Type::Video    => "EgIQAQ%3D%3D",
  Invidious::Search::Filters::Type::Channel  => "EgIQAg%3D%3D",
  Invidious::Search::Filters::Type::Playlist => "EgIQAw%3D%3D",
  Invidious::Search::Filters::Type::Movie    => "EgIQBA%3D%3D",
}

DURATION_FILTERS = {
  Invidious::Search::Filters::Duration::Short  => "EgIYAQ%3D%3D",
  Invidious::Search::Filters::Duration::Medium => "EgIYAw%3D%3D",
  Invidious::Search::Filters::Duration::Long   => "EgIYAg%3D%3D",
}

FEATURE_FILTERS = {
  Invidious::Search::Filters::Features::Live       => "EgJAAQ%3D%3D",
  Invidious::Search::Filters::Features::FourK      => "EgJwAQ%3D%3D",
  Invidious::Search::Filters::Features::HD         => "EgIgAQ%3D%3D",
  Invidious::Search::Filters::Features::Subtitles  => "EgIoAQ%3D%3D",
  Invidious::Search::Filters::Features::CCommons   => "EgIwAQ%3D%3D",
  Invidious::Search::Filters::Features::ThreeSixty => "EgJ4AQ%3D%3D",
  Invidious::Search::Filters::Features::VR180      => "EgPQAQE%3D",
  Invidious::Search::Filters::Features::ThreeD     => "EgI4AQ%3D%3D",
  Invidious::Search::Filters::Features::HDR        => "EgPIAQE%3D",
  Invidious::Search::Filters::Features::Location   => "EgO4AQE%3D",
  Invidious::Search::Filters::Features::Purchased  => "EgJIAQ%3D%3D",
}

SORT_FILTERS = {
  Invidious::Search::Filters::Sort::Relevance => "",
  Invidious::Search::Filters::Sort::Date      => "CAI%3D",
  Invidious::Search::Filters::Sort::Views     => "CAM%3D",
  Invidious::Search::Filters::Sort::Rating    => "CAE%3D",
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
