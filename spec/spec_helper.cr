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
require "spectator"

Spectator.configure do |config|
  config.fail_blank
  config.randomize
end
