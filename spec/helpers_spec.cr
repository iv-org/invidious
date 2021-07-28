require "kemal"
require "openssl/hmac"
require "pg"
require "protodec/utils"
require "spec"
require "yaml"
require "../src/invidious/helpers/*"
require "../src/invidious/channels/*"
require "../src/invidious/videos"
require "../src/invidious/comments"
require "../src/invidious/playlists"
require "../src/invidious/search"
require "../src/invidious/trending"
require "../src/invidious/users"

CONFIG = Config.from_yaml(File.open("config/config.example.yml"))

describe "Helper" do
  describe "#produce_channel_videos_url" do
    it "correctly produces url for requesting page `x` of a channel's videos" do
      produce_channel_videos_url(ucid: "UCXuqSBlHAE6Xw-yeJA0Tunw").should eq("/browse_ajax?continuation=4qmFsgI8EhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaIEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0V4&gl=US&hl=en")

      produce_channel_videos_url(ucid: "UCXuqSBlHAE6Xw-yeJA0Tunw", sort_by: "popular").should eq("/browse_ajax?continuation=4qmFsgJAEhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaJEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0V4R0FFPQ%3D%3D&gl=US&hl=en")

      produce_channel_videos_url(ucid: "UCXuqSBlHAE6Xw-yeJA0Tunw", page: 20).should eq("/browse_ajax?continuation=4qmFsgJAEhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaJEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0l5TUE9PQ%3D%3D&gl=US&hl=en")

      produce_channel_videos_url(ucid: "UC-9-kyTW8ZkZNDHQJ6FgpwQ", page: 20, sort_by: "popular").should eq("/browse_ajax?continuation=4qmFsgJAEhhVQy05LWt5VFc4WmtaTkRIUUo2Rmdwd1EaJEVnWjJhV1JsYjNNd0FqZ0JZQUZxQUxnQkFDQUFlZ0l5TUJnQg%3D%3D&gl=US&hl=en")
    end
  end

  describe "#produce_channel_search_continuation" do
    it "correctly produces token for searching a specific channel" do
      produce_channel_search_continuation("UCXuqSBlHAE6Xw-yeJA0Tunw", "", 100).should eq("4qmFsgJqEhhVQ1h1cVNCbEhBRTZYdy15ZUpBMFR1bncaIEVnWnpaV0Z5WTJnd0FUZ0JZQUY2QkVkS2IxaTRBUUE9WgCaAilicm93c2UtZmVlZFVDWHVxU0JsSEFFNlh3LXllSkEwVHVud3NlYXJjaA%3D%3D")

      produce_channel_search_continuation("UCXuqSBlHAE6Xw-yeJA0Tunw", "По ожиशुपतिरपि子而時ஸ்றீனி", 0).should eq("4qmFsgKoARIYVUNYdXFTQmxIQUU2WHcteWVKQTBUdW53GiBFZ1p6WldGeVkyZ3dBVGdCWUFGNkJFZEJRVDI0QVFBPVo-0J_QviDQvtC20LjgpLbgpYHgpKrgpKTgpL_gpLDgpKrgpL_lrZDogIzmmYLgrrjgr43grrHgr4Dgrqngrr-aAilicm93c2UtZmVlZFVDWHVxU0JsSEFFNlh3LXllSkEwVHVud3NlYXJjaA%3D%3D")
    end
  end

  describe "#produce_channel_playlists_url" do
    it "correctly produces a /browse_ajax URL with the given UCID and cursor" do
      produce_channel_playlists_url("UCCj956IF62FbT7Gouszaj9w", "AIOkY9EQpi_gyn1_QrFuZ1reN81_MMmI1YmlBblw8j7JHItEFG5h7qcJTNd4W9x5Quk_CVZ028gW").should eq("/browse_ajax?continuation=4qmFsgLNARIYVUNDajk1NklGNjJGYlQ3R291c3phajl3GrABRWdsd2JHRjViR2x6ZEhNd0FqZ0JZQUZxQUxnQkFIcG1VVlZzVUdFeGF6VlNWa1ozWVZZNWJtVlhOSGhZTVVaNVVtNVdZVTFZU214VWFtZDRXREF4VG1KVmEzaFhWekZ6VVcxS2MyUjZhSEZPTUhCSlUxaFNSbEpyWXpGaFJHUjRXVEJ3VlZSdFVUQldlbXcwVGxaR01XRXhPVVJXYkc5M1RXcG9ibFozSUFFWUF3PT0%3D&gl=US&hl=en")
    end
  end

  describe "#produce_playlist_continuation" do
    it "correctly produces ctoken for requesting index `x` of a playlist" do
      produce_playlist_continuation("UUCla9fZca4I7KagBtgRGnOw", 100).should eq("4qmFsgJNEhpWTFVVQ2xhOWZaY2E0STdLYWdCdGdSR25PdxoUQ0FGNkJsQlVPa05IVVElM0QlM0SaAhhVVUNsYTlmWmNhNEk3S2FnQnRnUkduT3c%3D")

      produce_playlist_continuation("UCCla9fZca4I7KagBtgRGnOw", 200).should eq("4qmFsgJLEhpWTFVVQ2xhOWZaY2E0STdLYWdCdGdSR25PdxoSQ0FKNkIxQlVPa05OWjBJJTNEmgIYVVVDbGE5ZlpjYTRJN0thZ0J0Z1JHbk93")

      produce_playlist_continuation("PL55713C70BA91BD6E", 100).should eq("4qmFsgJBEhRWTFBMNTU3MTNDNzBCQTkxQkQ2RRoUQ0FGNkJsQlVPa05IVVElM0QlM0SaAhJQTDU1NzEzQzcwQkE5MUJENkU%3D")
    end
  end

  describe "#produce_search_params" do
    it "correctly produces token for searching with specified filters" do
      produce_search_params.should eq("CAASAhABSAA%3D")

      produce_search_params(sort: "upload_date", content_type: "video").should eq("CAISAhABSAA%3D")

      produce_search_params(content_type: "playlist").should eq("CAASAhADSAA%3D")

      produce_search_params(sort: "date", content_type: "video", features: ["hd", "cc", "purchased", "hdr"]).should eq("CAISCxABIAEwAUgByAEBSAA%3D")

      produce_search_params(content_type: "channel").should eq("CAASAhACSAA%3D")
    end
  end

  describe "#produce_comment_continuation" do
    it "correctly produces a continuation token for comments" do
      produce_comment_continuation("_cE8xSu6swE", "ADSJ_i2qvJeFtL0htmS5_K5Ctj3eGFVBMWL9Wd42o3kmUL6_mAzdLp85-liQZL0mYr_16BhaggUqX652Sv9JqV6VXinShSP-ZT6rL4NolPBaPXVtJsO5_rA_qE3GubAuLFw9uzIIXU2-HnpXbdgPLWTFavfX206hqWmmpHwUOrmxQV_OX6tYkM3ux3rPAKCDrT8eWL7MU3bLiNcnbgkW8o0h8KYLL_8BPa8LcHbTv8pAoNkjerlX1x7K4pqxaXPoyz89qNlnh6rRx6AXgAzzoHH1dmcyQ8CIBeOHg-m4i8ZxdX4dP88XWrIFg-jJGhpGP8JUMDgZgavxVx225hUEYZMyrLGler5em4FgbG62YWC51moLDLeYEA").should eq("EkMSC19jRTh4U3U2c3dFyAEA4AEBogINKP___________wFAAMICHQgEGhdodHRwczovL3d3dy55b3V0dWJlLmNvbSIAGAYyjAMK9gJBRFNKX2kycXZKZUZ0TDBodG1TNV9LNUN0ajNlR0ZWQk1XTDlXZDQybzNrbVVMNl9tQXpkTHA4NS1saVFaTDBtWXJfMTZCaGFnZ1VxWDY1MlN2OUpxVjZWWGluU2hTUC1aVDZyTDROb2xQQmFQWFZ0SnNPNV9yQV9xRTNHdWJBdUxGdzl1eklJWFUyLUhucFhiZGdQTFdURmF2ZlgyMDZocVdtbXBId1VPcm14UVZfT1g2dFlrTTN1eDNyUEFLQ0RyVDhlV0w3TVUzYkxpTmNuYmdrVzhvMGg4S1lMTF84QlBhOExjSGJUdjhwQW9Oa2plcmxYMXg3SzRwcXhhWFBveXo4OXFObG5oNnJSeDZBWGdBenpvSEgxZG1jeVE4Q0lCZU9IZy1tNGk4WnhkWDRkUDg4WFdySUZnLWpKR2hwR1A4SlVNRGdaZ2F2eFZ4MjI1aFVFWVpNeXJMR2xlcjVlbTRGZ2JHNjJZV0M1MW1vTERMZVlFQSIPIgtfY0U4eFN1NnN3RTAAKBQ%3D")

      produce_comment_continuation("_cE8xSu6swE", "ADSJ_i1yz21HI4xrtsYXVC-2_kfZ6kx1yjYQumXAAxqH3CAd7ZxKxfLdZS1__fqhCtOASRbbpSBGH_tH1J96Dxux-Qfjk-lUbupMqv08Q3aHzGu7p70VoUMHhI2-GoJpnbpmcOxkGzeIuenRS_ym2Y8fkDowhqLPFgsS0n4djnZ2UmC17F3Ch3N1S1UYf1ZVOc991qOC1iW9kJDzyvRQTWCPsJUPneSaAKW-Rr97pdesOkR4i8cNvHZRnQKe2HEfsvlJOb2C3lF1dJBfJeNfnQYeh5hv6_fZN7bt3-JL1Xk3Qc9NXNxmmbDpwAC_yFR8dthFfUJdyIO9Nu1D79MLYeR-H5HxqUJokkJiGIz4lTE_CXXbhAI").should eq("EkMSC19jRTh4U3U2c3dFyAEA4AEBogINKP___________wFAAMICHQgEGhdodHRwczovL3d3dy55b3V0dWJlLmNvbSIAGAYyiQMK8wJBRFNKX2kxeXoyMUhJNHhydHNZWFZDLTJfa2ZaNmt4MXlqWVF1bVhBQXhxSDNDQWQ3WnhLeGZMZFpTMV9fZnFoQ3RPQVNSYmJwU0JHSF90SDFKOTZEeHV4LVFmamstbFVidXBNcXYwOFEzYUh6R3U3cDcwVm9VTUhoSTItR29KcG5icG1jT3hrR3plSXVlblJTX3ltMlk4ZmtEb3docUxQRmdzUzBuNGRqbloyVW1DMTdGM0NoM04xUzFVWWYxWlZPYzk5MXFPQzFpVzlrSkR6eXZSUVRXQ1BzSlVQbmVTYUFLVy1Scjk3cGRlc09rUjRpOGNOdkhaUm5RS2UySEVmc3ZsSk9iMkMzbEYxZEpCZkplTmZuUVllaDVodjZfZlpON2J0My1KTDFYazNRYzlOWE54bW1iRHB3QUNfeUZSOGR0aEZmVUpkeUlPOU51MUQ3OU1MWWVSLUg1SHhxVUpva2tKaUdJejRsVEVfQ1hYYmhBSSIPIgtfY0U4eFN1NnN3RTAAKBQ%3D")

      produce_comment_continuation("29-q7YnyUmY", "").should eq("EkMSCzI5LXE3WW55VW1ZyAEA4AEBogINKP___________wFAAMICHQgEGhdodHRwczovL3d3dy55b3V0dWJlLmNvbSIAGAYyFQoAIg8iCzI5LXE3WW55VW1ZMAAoFA%3D%3D")

      produce_comment_continuation("CvFH_6DNRCY", "").should eq("EkMSC0N2RkhfNkROUkNZyAEA4AEBogINKP___________wFAAMICHQgEGhdodHRwczovL3d3dy55b3V0dWJlLmNvbSIAGAYyFQoAIg8iC0N2RkhfNkROUkNZMAAoFA%3D%3D")
    end
  end

  describe "#produce_comment_reply_continuation" do
    it "correctly produces a continuation token for replies to a given comment" do
      produce_comment_reply_continuation("cIHQWOoJeag", "UCq6VFHwMzcMXbuKyG7SQYIg", "Ugx1IP_wGVv3WtGWcdV4AaABAg").should eq("EiYSC2NJSFFXT29KZWFnwAEByAEB4AEBogINKP___________wFAABgGMk0aSxIaVWd4MUlQX3dHVnYzV3RHV2NkVjRBYUFCQWciAggAKhhVQ3E2VkZId016Y01YYnVLeUc3U1FZSWcyC2NJSFFXT29KZWFnQAFICg%3D%3D")

      produce_comment_reply_continuation("cIHQWOoJeag", "UCq6VFHwMzcMXbuKyG7SQYIg", "Ugza62y_TlmTu9o2RfF4AaABAg").should eq("EiYSC2NJSFFXT29KZWFnwAEByAEB4AEBogINKP___________wFAABgGMk0aSxIaVWd6YTYyeV9UbG1UdTlvMlJmRjRBYUFCQWciAggAKhhVQ3E2VkZId016Y01YYnVLeUc3U1FZSWcyC2NJSFFXT29KZWFnQAFICg%3D%3D")

      produce_comment_reply_continuation("_cE8xSu6swE", "UC1AZY74-dGVPe6bfxFwwEMg", "UgyBUaRGHB9Jmt1dsUZ4AaABAg").should eq("EiYSC19jRTh4U3U2c3dFwAEByAEB4AEBogINKP___________wFAABgGMk0aSxIaVWd5QlVhUkdIQjlKbXQxZHNVWjRBYUFCQWciAggAKhhVQzFBWlk3NC1kR1ZQZTZiZnhGd3dFTWcyC19jRTh4U3U2c3dFQAFICg%3D%3D")
    end
  end

  describe "#produce_channel_community_continuation" do
    it "correctly produces a continuation token for a channel community" do
      produce_channel_community_continuation("UCZYTClx2T1of7BRZ86-8fow", "Egljb21tdW5pdHmqAxwKGFExQlBlV3htTkVaRlRrTmFkbTlCUXc9PSgHqAEA").should eq("4qmFsgJxEhhVQ1pZVENseDJUMW9mN0JSWjg2LThmb3caPEVnbGpiMjF0ZFc1cGRIbXFBeHdLR0ZFeFFsQmxWM2h0VGtWYVJsUnJUbUZrYlRsQ1VYYzlQU2dIcUFFQZoCFmJhY2tzdGFnZS1pdGVtLXNlY3Rpb24%3D")
      produce_channel_community_continuation("UCZYTClx2T1of7BRZ86-8fow", "Egljb21tdW5pdHmqAxwKGFEwOTJSbWcwVVVkRlMwTlFNeTF2UWc9PSgE").should eq("4qmFsgJtEhhVQ1pZVENseDJUMW9mN0JSWjg2LThmb3caOEVnbGpiMjF0ZFc1cGRIbXFBeHdLR0ZFd09USlNiV2N3VlZWa1JsTXdUbEZOZVRGMlVXYzlQU2dFmgIWYmFja3N0YWdlLWl0ZW0tc2VjdGlvbg%3D%3D")
      produce_channel_community_continuation("UCZYTClx2T1of7BRZ86-8fow", "Egljb21tdW5pdHmqAxwKGFEwdFhjREJ2UVVkRlRtbEdNMXB6UWc9PSgI").should eq("4qmFsgJtEhhVQ1pZVENseDJUMW9mN0JSWjg2LThmb3caOEVnbGpiMjF0ZFc1cGRIbXFBeHdLR0ZFd2RGaGpSRUoyVVZWa1JsUnRiRWROTVhCNlVXYzlQU2dJmgIWYmFja3N0YWdlLWl0ZW0tc2VjdGlvbg%3D%3D")
    end
  end

  describe "#extract_channel_community_cursor" do
    it "correctly extracts a community cursor from a given continuation" do
      extract_channel_community_cursor("4qmFsgJxEhhVQ1pZVENseDJUMW9mN0JSWjg2LThmb3caPEVnbGpiMjF0ZFc1cGRIbXFBeHdLR0ZFeFFsQmxWM2h0VGtWYVJsUnJUbUZrYlRsQ1VYYzlQU2dIcUFFQZoCFmJhY2tzdGFnZS1pdGVtLXNlY3Rpb24%3D").should eq("Egljb21tdW5pdHmqAxwKGFExQlBlV3htTkVaRlRrTmFkbTlCUXc9PSgHqAEA")
      extract_channel_community_cursor("4qmFsgJtEhhVQ1pZVENseDJUMW9mN0JSWjg2LThmb3caOEVnbGpiMjF0ZFc1cGRIbXFBeHdLR0ZFd09USlNiV2N3VlZWa1JsTXdUbEZOZVRGMlVXYzlQU2dFmgIWYmFja3N0YWdlLWl0ZW0tc2VjdGlvbg%3D%3D").should eq("Egljb21tdW5pdHmqAxwKGFEwOTJSbWcwVVVkRlMwTlFNeTF2UWc9PSgE")
      extract_channel_community_cursor("4qmFsgJtEhhVQ1pZVENseDJUMW9mN0JSWjg2LThmb3caOEVnbGpiMjF0ZFc1cGRIbXFBeHdLR0ZFd2RGaGpSRUoyVVZWa1JsUnRiRWROTVhCNlVXYzlQU2dJmgIWYmFja3N0YWdlLWl0ZW0tc2VjdGlvbg%3D%3D").should eq("Egljb21tdW5pdHmqAxwKGFEwdFhjREJ2UVVkRlRtbEdNMXB6UWc9PSgI")
    end
  end

  describe "#extract_plid" do
    it "correctly extracts playlist ID from trending URL" do
      extract_plid("/feed/trending?bp=4gIuCggvbS8wNHJsZhIiUExGZ3F1TG5MNTlhbVBud2pLbmNhZUp3MDYzZlU1M3Q0cA%3D%3D").should eq("PLFgquLnL59amPnwjKncaeJw063fU53t4p")
      extract_plid("/feed/trending?bp=4gIvCgkvbS8wYnp2bTISIlBMaUN2Vkp6QnVwS2tDaFNnUDdGWFhDclo2aEp4NmtlTm0%3D").should eq("PLiCvVJzBupKkChSgP7FXXCrZ6hJx6keNm")
      extract_plid("/feed/trending?bp=4gIuCggvbS8wNWpoZxIiUEwzWlE1Q3BOdWxRbUtPUDNJekdsYWN0V1c4dklYX0hFUA%3D%3D").should eq("PL3ZQ5CpNulQmKOP3IzGlactWW8vIX_HEP")
      extract_plid("/feed/trending?bp=4gIuCggvbS8wMnZ4bhIiUEx6akZiYUZ6c21NUnFhdEJnVTdPeGNGTkZhQ2hqTkVERA%3D%3D").should eq("PLzjFbaFzsmMRqatBgU7OxcFNFaChjNEDD")
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
