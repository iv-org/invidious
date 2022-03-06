require "../../../src/invidious/search/filters"

require "http/params"
require "spectator"

Spectator.configure do |config|
  config.fail_blank
  config.randomize
end

FEATURES_TEXT = {
  Invidious::Search::Filters::Features::Live       => "live",
  Invidious::Search::Filters::Features::FourK      => "4k",
  Invidious::Search::Filters::Features::HD         => "hd",
  Invidious::Search::Filters::Features::Subtitles  => "subtitles",
  Invidious::Search::Filters::Features::CCommons   => "commons",
  Invidious::Search::Filters::Features::ThreeSixty => "360",
  Invidious::Search::Filters::Features::VR180      => "vr180",
  Invidious::Search::Filters::Features::ThreeD     => "3d",
  Invidious::Search::Filters::Features::HDR        => "hdr",
  Invidious::Search::Filters::Features::Location   => "location",
  Invidious::Search::Filters::Features::Purchased  => "purchased",
}

Spectator.describe Invidious::Search::Filters do
  # -------------------
  #  Decode (legacy)
  # -------------------

  describe "#from_legacy_filters" do
    it "Decodes channel: filter" do
      query = "test channel:UC123456 request"

      fltr, chan, qury, subs = described_class.from_legacy_filters(query)

      expect(fltr).to eq(described_class.new)
      expect(chan).to eq("UC123456")
      expect(qury).to eq("test request")
      expect(subs).to be_false
    end

    it "Decodes user: filter" do
      query = "user:LinusTechTips broke something (again)"

      fltr, chan, qury, subs = described_class.from_legacy_filters(query)

      expect(fltr).to eq(described_class.new)
      expect(chan).to eq("LinusTechTips")
      expect(qury).to eq("broke something (again)")
      expect(subs).to be_false
    end

    it "Decodes type: filter" do
      Invidious::Search::Filters::Type.each do |value|
        query = "Eiffel 65 - Blue [1 Hour] type:#{value}"

        fltr, chan, qury, subs = described_class.from_legacy_filters(query)

        expect(fltr).to eq(described_class.new(type: value))
        expect(chan).to eq("")
        expect(qury).to eq("Eiffel 65 - Blue [1 Hour]")
        expect(subs).to be_false
      end
    end

    it "Decodes content_type: filter" do
      Invidious::Search::Filters::Type.each do |value|
        query = "I like to watch content_type:#{value}"

        fltr, chan, qury, subs = described_class.from_legacy_filters(query)

        expect(fltr).to eq(described_class.new(type: value))
        expect(chan).to eq("")
        expect(qury).to eq("I like to watch")
        expect(subs).to be_false
      end
    end

    it "Decodes date: filter" do
      Invidious::Search::Filters::Date.each do |value|
        query = "This date:#{value} is old!"

        fltr, chan, qury, subs = described_class.from_legacy_filters(query)

        expect(fltr).to eq(described_class.new(date: value))
        expect(chan).to eq("")
        expect(qury).to eq("This is old!")
        expect(subs).to be_false
      end
    end

    it "Decodes duration: filter" do
      Invidious::Search::Filters::Duration.each do |value|
        query = "This duration:#{value} is old!"

        fltr, chan, qury, subs = described_class.from_legacy_filters(query)

        expect(fltr).to eq(described_class.new(duration: value))
        expect(chan).to eq("")
        expect(qury).to eq("This is old!")
        expect(subs).to be_false
      end
    end

    it "Decodes feature: filter" do
      Invidious::Search::Filters::Features.each do |value|
        string = FEATURES_TEXT[value]
        query = "I like my precious feature:#{string} ^^"

        fltr, chan, qury, subs = described_class.from_legacy_filters(query)

        expect(fltr).to eq(described_class.new(features: value))
        expect(chan).to eq("")
        expect(qury).to eq("I like my precious ^^")
        expect(subs).to be_false
      end
    end

    it "Decodes features: filter" do
      query = "This search has many features:vr180,cc,hdr :o"

      fltr, chan, qury, subs = described_class.from_legacy_filters(query)

      features = Invidious::Search::Filters::Features.flags(HDR, VR180, CCommons)

      expect(fltr).to eq(described_class.new(features: features))
      expect(chan).to eq("")
      expect(qury).to eq("This search has many :o")
      expect(subs).to be_false
    end

    it "Decodes sort: filter" do
      Invidious::Search::Filters::Sort.each do |value|
        query = "Computer? sort:#{value} my files!"

        fltr, chan, qury, subs = described_class.from_legacy_filters(query)

        expect(fltr).to eq(described_class.new(sort: value))
        expect(chan).to eq("")
        expect(qury).to eq("Computer? my files!")
        expect(subs).to be_false
      end
    end

    it "Decodes subscriptions: filter" do
      query = "enable subscriptions:true"

      fltr, chan, qury, subs = described_class.from_legacy_filters(query)

      expect(fltr).to eq(described_class.new)
      expect(chan).to eq("")
      expect(qury).to eq("enable")
      expect(subs).to be_true
    end

    it "Ignores junk data" do
      query = "duration:I sort:like type:cleaning features:stuff date:up!"

      fltr, chan, qury, subs = described_class.from_legacy_filters(query)

      expect(fltr).to eq(described_class.new)
      expect(chan).to eq("")
      expect(qury).to eq("")
      expect(subs).to be_false
    end

    it "Keeps unknown keys" do
      query = "to:be or:not to:be"

      fltr, chan, qury, subs = described_class.from_legacy_filters(query)

      expect(fltr).to eq(described_class.new)
      expect(chan).to eq("")
      expect(qury).to eq("to:be or:not to:be")
      expect(subs).to be_false
    end
  end

  # -------------------
  #  Decode (URL)
  # -------------------

  describe "#from_iv_params" do
    it "Decodes type= filter" do
      Invidious::Search::Filters::Type.each do |value|
        params = HTTP::Params.parse("type=#{value}")

        expect(described_class.from_iv_params(params))
          .to eq(described_class.new(type: value))
      end
    end

    it "Decodes date= filter" do
      Invidious::Search::Filters::Date.each do |value|
        params = HTTP::Params.parse("date=#{value}")

        expect(described_class.from_iv_params(params))
          .to eq(described_class.new(date: value))
      end
    end

    it "Decodes duration= filter" do
      Invidious::Search::Filters::Duration.each do |value|
        params = HTTP::Params.parse("duration=#{value}")

        expect(described_class.from_iv_params(params))
          .to eq(described_class.new(duration: value))
      end
    end

    it "Decodes features= filter (single)" do
      Invidious::Search::Filters::Features.each do |value|
        string = described_class.format_features(value)
        params = HTTP::Params.parse("features=#{string}")

        expect(described_class.from_iv_params(params))
          .to eq(described_class.new(features: value))
      end
    end

    it "Decodes features= filter (multiple - comma separated)" do
      features = Invidious::Search::Filters::Features.flags(HDR, VR180, CCommons)
      params = HTTP::Params.parse("features=vr180%2Ccc%2Chdr") # %2C is a comma

      expect(described_class.from_iv_params(params))
        .to eq(described_class.new(features: features))
    end

    it "Decodes features= filter (multiple - URL parameters)" do
      features = Invidious::Search::Filters::Features.flags(ThreeSixty, HD, FourK)
      params = HTTP::Params.parse("features=4k&features=360&features=hd")

      expect(described_class.from_iv_params(params))
        .to eq(described_class.new(features: features))
    end

    it "Decodes sort= filter" do
      Invidious::Search::Filters::Sort.each do |value|
        params = HTTP::Params.parse("sort=#{value}")

        expect(described_class.from_iv_params(params))
          .to eq(described_class.new(sort: value))
      end
    end

    it "Ignores junk data" do
      params = HTTP::Params.parse("foo=bar&sort=views&answer=42&type=channel")

      expect(described_class.from_iv_params(params)).to eq(
        described_class.new(
          sort: Invidious::Search::Filters::Sort::Views,
          type: Invidious::Search::Filters::Type::Channel
        )
      )
    end
  end
end
