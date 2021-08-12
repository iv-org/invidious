require "pg"
require "kemal"
require "../src/invidious/helpers/logger"
require "../src/invidious/helpers/youtube_api"
require "../src/invidious/helpers/macros"
require "../src/invidious/helpers/extractors"

# To avoid importing invidious.cr we'll go ahead and define these two constants in here.
LOGGER  = Invidious::LogHandler.new(STDOUT, LogLevel::Info)
YT_POOL = YoutubeConnectionPool.new(URI.parse("https://www.youtube.com"), capacity: 100, timeout: 2.0, use_quic: true)

it "Extracts search results" do
  extract_items(YoutubeAPI.search("kurzgesagt", "CABIAA%3D%3D"))
end

describe "Channel" do
  it "Extracts video results" do
    extract_items(YoutubeAPI.browse("UCsXVk37bltHxD1rDPwtNM8Q", params: "EgZ2aWRlb3M%3D")).size.should be > 1
  end

  it "Extracts playlist results" do
    extract_items(YoutubeAPI.browse("UCsXVk37bltHxD1rDPwtNM8Q", params: "EglwbGF5bGlzdHM%3D")).size.should be > 1
  end
end
