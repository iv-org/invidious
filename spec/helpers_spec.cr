require "kemal"
require "openssl/hmac"
require "pg"
require "spec"
require "yaml"
require "../src/invidious/helpers/*"
require "../src/invidious/channels"
require "../src/invidious/comments"
require "../src/invidious/playlists"
require "../src/invidious/search"
require "../src/invidious/users"

describe "Helper" do
  describe "#produce_channel_videos_url" do
    it "correctly produces url for requesting page `x` of a channel's videos" do
      produce_channel_videos_url(ucid: "UCXuqSBlHAE6Xw-yeJA0Tunw").should eq("/browse_ajax?continuation=4qmFsgI8EhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaIEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0V4&gl=US&hl=en")

      produce_channel_videos_url(ucid: "UCXuqSBlHAE6Xw-yeJA0Tunw", sort_by: "popular").should eq("/browse_ajax?continuation=4qmFsgJCEhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaJkVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0V4R0FFJTNE&gl=US&hl=en")

      produce_channel_videos_url(ucid: "UCXuqSBlHAE6Xw-yeJA0Tunw", page: 20).should eq("/browse_ajax?continuation=4qmFsgJEEhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaKEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0l5TUElM0QlM0Q%3D&gl=US&hl=en")

      produce_channel_videos_url(ucid: "UC-9-kyTW8ZkZNDHQJ6FgpwQ", page: 20, sort_by: "popular").should eq("/browse_ajax?continuation=4qmFsgJAEhhVQy05LWt5VFc4WmtaTkRIUUo2Rmdwd1EaJEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0l5TUJnQg%3D%3D&gl=US&hl=en")
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

  describe "#produce_comment_continuation" do
    it "correctly produces a continuation token for comments" do
      produce_comment_continuation("_cE8xSu6swE", "ADSJ_i2qvJeFtL0htmS5_K5Ctj3eGFVBMWL9Wd42o3kmUL6_mAzdLp85-liQZL0mYr_16BhaggUqX652Sv9JqV6VXinShSP-ZT6rL4NolPBaPXVtJsO5_rA_qE3GubAuLFw9uzIIXU2-HnpXbdgPLWTFavfX206hqWmmpHwUOrmxQV_OX6tYkM3ux3rPAKCDrT8eWL7MU3bLiNcnbgkW8o0h8KYLL_8BPa8LcHbTv8pAoNkjerlX1x7K4pqxaXPoyz89qNlnh6rRx6AXgAzzoHH1dmcyQ8CIBeOHg-m4i8ZxdX4dP88XWrIFg-jJGhpGP8JUMDgZgavxVx225hUEYZMyrLGler5em4FgbG62YWC51moLDLeYEA").should eq("EiYSC19jRTh4U3U2c3dFwAEByAEB4AEBogINKP___________wFAABgGMowDCvYCQURTSl9pMnF2SmVGdEwwaHRtUzVfSzVDdGozZUdGVkJNV0w5V2Q0Mm8za21VTDZfbUF6ZExwODUtbGlRWkwwbVlyXzE2QmhhZ2dVcVg2NTJTdjlKcVY2VlhpblNoU1AtWlQ2ckw0Tm9sUEJhUFhWdEpzTzVfckFfcUUzR3ViQXVMRnc5dXpJSVhVMi1IbnBYYmRnUExXVEZhdmZYMjA2aHFXbW1wSHdVT3JteFFWX09YNnRZa00zdXgzclBBS0NEclQ4ZVdMN01VM2JMaU5jbmJna1c4bzBoOEtZTExfOEJQYThMY0hiVHY4cEFvTmtqZXJsWDF4N0s0cHF4YVhQb3l6ODlxTmxuaDZyUng2QVhnQXp6b0hIMWRtY3lROENJQmVPSGctbTRpOFp4ZFg0ZFA4OFhXcklGZy1qSkdocEdQOEpVTURnWmdhdnhWeDIyNWhVRVlaTXlyTEdsZXI1ZW00RmdiRzYyWVdDNTFtb0xETGVZRUEiDyILX2NFOHhTdTZzd0UwACgU")

      produce_comment_continuation("_cE8xSu6swE", "ADSJ_i1yz21HI4xrtsYXVC-2_kfZ6kx1yjYQumXAAxqH3CAd7ZxKxfLdZS1__fqhCtOASRbbpSBGH_tH1J96Dxux-Qfjk-lUbupMqv08Q3aHzGu7p70VoUMHhI2-GoJpnbpmcOxkGzeIuenRS_ym2Y8fkDowhqLPFgsS0n4djnZ2UmC17F3Ch3N1S1UYf1ZVOc991qOC1iW9kJDzyvRQTWCPsJUPneSaAKW-Rr97pdesOkR4i8cNvHZRnQKe2HEfsvlJOb2C3lF1dJBfJeNfnQYeh5hv6_fZN7bt3-JL1Xk3Qc9NXNxmmbDpwAC_yFR8dthFfUJdyIO9Nu1D79MLYeR-H5HxqUJokkJiGIz4lTE_CXXbhAI").should eq("EiYSC19jRTh4U3U2c3dFwAEByAEB4AEBogINKP___________wFAABgGMokDCvMCQURTSl9pMXl6MjFISTR4cnRzWVhWQy0yX2tmWjZreDF5allRdW1YQUF4cUgzQ0FkN1p4S3hmTGRaUzFfX2ZxaEN0T0FTUmJicFNCR0hfdEgxSjk2RHh1eC1RZmprLWxVYnVwTXF2MDhRM2FIekd1N3A3MFZvVU1IaEkyLUdvSnBuYnBtY094a0d6ZUl1ZW5SU195bTJZOGZrRG93aHFMUEZnc1MwbjRkam5aMlVtQzE3RjNDaDNOMVMxVVlmMVpWT2M5OTFxT0MxaVc5a0pEenl2UlFUV0NQc0pVUG5lU2FBS1ctUnI5N3BkZXNPa1I0aThjTnZIWlJuUUtlMkhFZnN2bEpPYjJDM2xGMWRKQmZKZU5mblFZZWg1aHY2X2ZaTjdidDMtSkwxWGszUWM5TlhOeG1tYkRwd0FDX3lGUjhkdGhGZlVKZHlJTzlOdTFENzlNTFllUi1INUh4cVVKb2trSmlHSXo0bFRFX0NYWGJoQUkiDyILX2NFOHhTdTZzd0UwACgU")

      produce_comment_continuation("29-q7YnyUmY", "").should eq("EiYSCzI5LXE3WW55VW1ZwAEByAEB4AEBogINKP___________wFAABgGMhMiDyILMjktcTdZbnlVbVkwAHgC")

      produce_comment_continuation("CvFH_6DNRCY", "").should eq("EiYSC0N2RkhfNkROUkNZwAEByAEB4AEBogINKP___________wFAABgGMhMiDyILQ3ZGSF82RE5SQ1kwAHgC")
    end
  end

  describe "#produce_comment_reply_continuation" do
    it "correctly produces a continuation token for replies to a given comment" do
      produce_comment_reply_continuation("cIHQWOoJeag", "UCq6VFHwMzcMXbuKyG7SQYIg", "Ugx1IP_wGVv3WtGWcdV4AaABAg").should eq("EiYSC2NJSFFXT29KZWFnwAEByAEB4AEBogINKP___________wFAABgGMk0aSxIaVWd4MUlQX3dHVnYzV3RHV2NkVjRBYUFCQWciAggAKhhVQ3E2VkZId016Y01YYnVLeUc3U1FZSWcyC2NJSFFXT29KZWFnQAFICg%3D%3D")

      produce_comment_reply_continuation("cIHQWOoJeag", "UCq6VFHwMzcMXbuKyG7SQYIg", "Ugza62y_TlmTu9o2RfF4AaABAg").should eq("EiYSC2NJSFFXT29KZWFnwAEByAEB4AEBogINKP___________wFAABgGMk0aSxIaVWd6YTYyeV9UbG1UdTlvMlJmRjRBYUFCQWciAggAKhhVQ3E2VkZId016Y01YYnVLeUc3U1FZSWcyC2NJSFFXT29KZWFnQAFICg%3D%3D")

      produce_comment_reply_continuation("_cE8xSu6swE", "UC1AZY74-dGVPe6bfxFwwEMg", "UgyBUaRGHB9Jmt1dsUZ4AaABAg").should eq("EiYSC19jRTh4U3U2c3dFwAEByAEB4AEBogINKP___________wFAABgGMk0aSxIaVWd5QlVhUkdIQjlKbXQxZHNVWjRBYUFCQWciAggAKhhVQzFBWlk3NC1kR1ZQZTZiZnhGd3dFTWcyC19jRTh4U3U2c3dFQAFICg%3D%3D")
    end
  end

  describe "#sign_token" do
    it "correctly signs a given hash" do
      token = {
        "session" => "v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "expires" => 1554680038,
        "scopes"  => [
          ":notifications",
          ":subscriptions/*",
          "GET:tokens*",
        ],
        "signature" => "f__2hS20th8pALF305PJFK-D2aVtvefNnQheILHD2vU=",
      }
      sign_token("SECRET_KEY", token).should eq(token["signature"])

      token = {
        "session"   => "v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "scopes"    => [":notifications", "POST:subscriptions/*"],
        "signature" => "fNvXoT0MRAL9eE6lTE33CEg8HitYJDOL9a22rSN2Ihg=",
      }
      sign_token("SECRET_KEY", token).should eq(token["signature"])
    end
  end
end
