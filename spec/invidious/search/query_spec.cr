require "../../../src/invidious/search/filters"
require "../../../src/invidious/search/query"

require "http/params"
require "spectator"

Spectator.configure do |config|
  config.fail_blank
  config.randomize
end

Spectator.describe Invidious::Search::Query do
  describe Type::Regular do
    # -------------------
    #  Query parsing
    # -------------------

    it "parses query with URL prameters (q)" do
      query = described_class.new(
        HTTP::Params.parse("q=What+is+Love+10+hour&type=video&duration=long"),
        Invidious::Search::Query::Type::Regular, nil
      )

      expect(query.type).to eq(Invidious::Search::Query::Type::Regular)
      expect(query.channel).to be_empty
      expect(query.text).to eq("What is Love 10 hour")

      expect(query.filters).to eq(
        Invidious::Search::Filters.new(
          type: Invidious::Search::Filters::Type::Video,
          duration: Invidious::Search::Filters::Duration::Long
        )
      )
    end

    it "parses query with URL prameters (search_query)" do
      query = described_class.new(
        HTTP::Params.parse("search_query=What+is+Love+10+hour&type=video&duration=long"),
        Invidious::Search::Query::Type::Regular, nil
      )

      expect(query.type).to eq(Invidious::Search::Query::Type::Regular)
      expect(query.channel).to be_empty
      expect(query.text).to eq("What is Love 10 hour")

      expect(query.filters).to eq(
        Invidious::Search::Filters.new(
          type: Invidious::Search::Filters::Type::Video,
          duration: Invidious::Search::Filters::Duration::Long
        )
      )
    end

    it "parses query with legacy filters (q)" do
      query = described_class.new(
        HTTP::Params.parse("q=Nyan+cat+duration:long"),
        Invidious::Search::Query::Type::Regular, nil
      )

      expect(query.type).to eq(Invidious::Search::Query::Type::Regular)
      expect(query.channel).to be_empty
      expect(query.text).to eq("Nyan cat")

      expect(query.filters).to eq(
        Invidious::Search::Filters.new(
          duration: Invidious::Search::Filters::Duration::Long
        )
      )
    end

    it "parses query with legacy filters (search_query)" do
      query = described_class.new(
        HTTP::Params.parse("search_query=Nyan+cat+duration:long"),
        Invidious::Search::Query::Type::Regular, nil
      )

      expect(query.type).to eq(Invidious::Search::Query::Type::Regular)
      expect(query.channel).to be_empty
      expect(query.text).to eq("Nyan cat")

      expect(query.filters).to eq(
        Invidious::Search::Filters.new(
          duration: Invidious::Search::Filters::Duration::Long
        )
      )
    end

    it "parses query with both URL params and legacy filters" do
      query = described_class.new(
        HTTP::Params.parse("q=Vamos+a+la+playa+duration:long&type=Video&date=year"),
        Invidious::Search::Query::Type::Regular, nil
      )

      expect(query.type).to eq(Invidious::Search::Query::Type::Regular)
      expect(query.channel).to be_empty
      expect(query.text).to eq("Vamos a la playa duration:long")

      expect(query.filters).to eq(
        Invidious::Search::Filters.new(
          type: Invidious::Search::Filters::Type::Video,
          date: Invidious::Search::Filters::Date::Year
        )
      )
    end

    # -------------------
    #  Type switching
    # -------------------

    it "switches to channel search (URL param)" do
      query = described_class.new(
        HTTP::Params.parse("q=thunderbolt+4&channel=UC0vBXGSyV14uvJ4hECDOl0Q"),
        Invidious::Search::Query::Type::Regular, nil
      )

      expect(query.type).to eq(Invidious::Search::Query::Type::Channel)
      expect(query.channel).to eq("UC0vBXGSyV14uvJ4hECDOl0Q")
      expect(query.text).to eq("thunderbolt 4")
      expect(query.filters.default?).to be_true
    end

    it "switches to channel search (legacy)" do
      query = described_class.new(
        HTTP::Params.parse("q=channel%3AUCRPdsCVuH53rcbTcEkuY4uQ+rdna3"),
        Invidious::Search::Query::Type::Regular, nil
      )

      expect(query.type).to eq(Invidious::Search::Query::Type::Channel)
      expect(query.channel).to eq("UCRPdsCVuH53rcbTcEkuY4uQ")
      expect(query.text).to eq("rdna3")
      expect(query.filters.default?).to be_true
    end

    it "switches to subscriptions search" do
      query = described_class.new(
        HTTP::Params.parse("q=subscriptions:true+tunak+tunak+tun"),
        Invidious::Search::Query::Type::Regular, nil
      )

      expect(query.type).to eq(Invidious::Search::Query::Type::Subscriptions)
      expect(query.channel).to be_empty
      expect(query.text).to eq("tunak tunak tun")
      expect(query.filters.default?).to be_true
    end
  end

  describe Type::Channel do
    it "ignores extra parameters" do
      query = described_class.new(
        HTTP::Params.parse("q=Take+on+me+channel%3AUC12345679&type=video&date=year"),
        Invidious::Search::Query::Type::Channel, nil
      )

      expect(query.type).to eq(Invidious::Search::Query::Type::Channel)
      expect(query.channel).to be_empty
      expect(query.text).to eq("Take on me")
      expect(query.filters.default?).to be_true
    end
  end

  describe Type::Subscriptions do
    it "works" do
      query = described_class.new(
        HTTP::Params.parse("q=Harlem+shake&type=video&date=year"),
        Invidious::Search::Query::Type::Subscriptions, nil
      )

      expect(query.type).to eq(Invidious::Search::Query::Type::Subscriptions)
      expect(query.channel).to be_empty
      expect(query.text).to eq("Harlem shake")

      expect(query.filters).to eq(
        Invidious::Search::Filters.new(
          type: Invidious::Search::Filters::Type::Video,
          date: Invidious::Search::Filters::Date::Year
        )
      )
    end
  end

  describe Type::Playlist do
    it "ignores extra parameters" do
      query = described_class.new(
        HTTP::Params.parse("q=Harlem+shake+type:video+date:year&channel=UC12345679"),
        Invidious::Search::Query::Type::Playlist, nil
      )

      expect(query.type).to eq(Invidious::Search::Query::Type::Playlist)
      expect(query.channel).to be_empty
      expect(query.text).to eq("Harlem shake")

      expect(query.filters).to eq(
        Invidious::Search::Filters.new(
          type: Invidious::Search::Filters::Type::Video,
          date: Invidious::Search::Filters::Date::Year
        )
      )
    end
  end
end
