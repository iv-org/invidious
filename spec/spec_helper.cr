require "kemal"
require "openssl/hmac"
require "pg"
require "protodec/utils"
require "yaml"
require "../src/invidious/helpers/*"
require "../src/invidious/channels/*"
require "../src/invidious/videos/caption"
require "../src/invidious/videos"
require "../src/invidious/playlists"
require "../src/invidious/search/ctoken"
require "../src/invidious/trending"
require "../src/invidious/config"
require "../src/invidious/user/preferences.cr"
require "../src/invidious/jobs"
require "../src/invidious/jobs/*"
require "spectator"

CONFIG = Config.from_yaml(File.open("config/config.example.yml"))

Spectator.configure do |config|
  config.fail_blank
  config.randomize
end
