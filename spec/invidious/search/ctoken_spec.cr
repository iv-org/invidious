require "../../spec_helper"

Spectator.describe Invidious::Search::CToken do
  describe ".produce_channel_search_continuation" do
    it "correctly produces token for searching a specific channel" do
      expect(Invidious::Search::CToken.produce_channel_search_continuation("UCXuqSBlHAE6Xw-yeJA0Tunw", "", 100)).to eq("4qmFsgJqEhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaIEVnWnpaV0Z5WTJnd0FUZ0JZQUY2QkVkS2IxaTRBUUE9WgCaAilicm93c2UtZmVlZFVDWHVxU0JsSEFFNlh3LXllSkEwVHVud3NlYXJjaA%3D%3D")

      expect(Invidious::Search::CToken.produce_channel_search_continuation("UCXuqSBlHAE6Xw-yeJA0Tunw", "По ожиशुपतिरपि子而時ஸ்றீனி", 0)).to eq("4qmFsgKoARIYVUNYdXFTQmxIQUU2WHcteWVKQTBUdW53GiBFZ1p6WldGeVkyZ3dBVGdCWUFGNkJFZEJRVDI0QVFBPVo-0J_QviDQvtC20LjgpLbgpYHgpKrgpKTgpL_gpLDgpKrgpL_lrZDogIzmmYLgrrjgr43grrHgr4Dgrqngrr-aAilicm93c2UtZmVlZFVDWHVxU0JsSEFFNlh3LXllSkEwVHVud3NlYXJjaA%3D%3D")
    end
  end
end
