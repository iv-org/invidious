require "kemal"
require "pg"
require "spec"
require "yaml"
require "../src/invidious/helpers/*"
require "../src/invidious/channels"
require "../src/invidious/playlists"
require "../src/invidious/search"

describe "Helpers" do
  describe "#produce_channel_videos_url" do
    it "correctly produces url for requesting page `x` of a channel's videos" do
      produce_channel_videos_url(ucid: "UCXuqSBlHAE6Xw-yeJA0Tunw").should eq("/browse_ajax?continuation=4qmFsgI8EhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaIEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0V4&gl=US&hl=en")

      produce_channel_videos_url(ucid: "UCXuqSBlHAE6Xw-yeJA0Tunw", sort_by: "popular").should eq("/browse_ajax?continuation=4qmFsgJCEhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaJkVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0V4R0FFJTNE&gl=US&hl=en")

      produce_channel_videos_url(ucid: "UCXuqSBlHAE6Xw-yeJA0Tunw", page: 20).should eq("/browse_ajax?continuation=4qmFsgJEEhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaKEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0l5TUElM0QlM0Q%3D&gl=US&hl=en")

      produce_channel_videos_url(ucid: "UC-9-kyTW8ZkZNDHQJ6FgpwQ", auto_generated: true).should eq("/browse_ajax?continuation=4qmFsgJIEhhVQy05LWt5VFc4WmtaTkRIUUo2Rmdwd1EaLEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQTJlZ294TlRVeU1ESXlPVFE1&gl=US&hl=en")

      produce_channel_videos_url(ucid: "UC-9-kyTW8ZkZNDHQJ6FgpwQ", page: 20, auto_generated: true, sort_by: "popular").should eq("/browse_ajax?continuation=4qmFsgJOEhhVQy05LWt5VFc4WmtaTkRIUUo2Rmdwd1EaMkVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQTJlZ294TlRBeU1UY3dNVFE1R0FFJTNE&gl=US&hl=en")
    end
  end

  describe "#produce_channel_search_url" do
    it "correctly produces token for searching a specific channel" do
      produce_channel_search_url("UCXuqSBlHAE6Xw-yeJA0Tunw", "", 100).should eq("/browse_ajax?continuation=4qmFsgI-EhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaIEVnWnpaV0Z5WTJnd0FqZ0JZQUZxQUxnQkFIb0RNVEF3WgA%3D&gl=US&hl=en")

      produce_channel_search_url("UCXuqSBlHAE6Xw-yeJA0Tunw", "По ожиशुपतिरपि子而時ஸ்றீனி", 0).should eq("/browse_ajax?continuation=4qmFsgJZEhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaJEVnWnpaV0Z5WTJnd0FqZ0JZQUZxQUxnQkFIb0JNQSUzRCUzRFoX0J_QviDQvtC20LjgpLbgpYHgpKrgpKTgpL_gpLDgpKrgpL_lrZDogIzmmYLgrrjgr43grrHgr4Dgrqngrr8%3D&gl=US&hl=en")
    end
  end

  describe "#produce_playlist_url" do
    it "correctly produces url for requesting index `x` of a playlist" do
      produce_playlist_url("UUCla9fZca4I7KagBtgRGnOw", 0).should eq("/browse_ajax?continuation=4qmFsgIsEhpWTFVVQ2xhOWZaY2E0STdLYWdCdGdSR25PdxoOZWdaUVZEcERRVUUlM0Q%3D&gl=US&hl=en")

      produce_playlist_url("UCCla9fZca4I7KagBtgRGnOw", 0).should eq("/browse_ajax?continuation=4qmFsgIsEhpWTFVVQ2xhOWZaY2E0STdLYWdCdGdSR25PdxoOZWdaUVZEcERRVUUlM0Q%3D&gl=US&hl=en")

      produce_playlist_url("PLt5AfwLFPxWLNVixpe1w3fi6lE2OTq0ET", 0).should eq("/browse_ajax?continuation=4qmFsgI2EiRWTFBMdDVBZndMRlB4V0xOVml4cGUxdzNmaTZsRTJPVHEwRVQaDmVnWlFWRHBEUVVFJTNE&gl=US&hl=en")

      produce_playlist_url("PLt5AfwLFPxWLNVixpe1w3fi6lE2OTq0ET", 10000).should eq("/browse_ajax?continuation=4qmFsgI0EiRWTFBMdDVBZndMRlB4V0xOVml4cGUxdzNmaTZsRTJPVHEwRVQaDGVnZFFWRHBEU2tKUA%3D%3D&gl=US&hl=en")

      produce_playlist_url("PL55713C70BA91BD6E", 0).should eq("/browse_ajax?continuation=4qmFsgImEhRWTFBMNTU3MTNDNzBCQTkxQkQ2RRoOZWdaUVZEcERRVUUlM0Q%3D&gl=US&hl=en")

      produce_playlist_url("PL55713C70BA91BD6E", 10000).should eq("/browse_ajax?continuation=4qmFsgIkEhRWTFBMNTU3MTNDNzBCQTkxQkQ2RRoMZWdkUVZEcERTa0pQ&gl=US&hl=en")
    end
  end

  describe "#produce_search_params" do
    it "correctly produces token for searching with specified filters" do
      produce_search_params.should eq("CAASAhAB")

      produce_search_params(sort: "upload_date", content_type: "video").should eq("CAISAhAB")

      produce_search_params(content_type: "playlist").should eq("CAASAhAD")

      produce_search_params(sort: "date", content_type: "video", features: ["hd", "cc", "purchased", "hdr"]).should eq("CAISCxABIAEwAUgByAEB")

      produce_search_params(content_type: "channel").should eq("CAASAhAC")
    end
  end
end
