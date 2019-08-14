require "spec"
require "lucky_flow"
require "http"
require "../src/exception_page"
require "./support/**"

include LuckyFlow::Expectations

server = TestServer.new(3002)

LuckyFlow.configure do |settings|
  settings.base_uri = "http://localhost:3002"
  settings.stop_retrying_after = 40.milliseconds
end

spawn do
  server.listen
end

at_exit do
  LuckyFlow.shutdown
  server.close
end

Habitat.raise_if_missing_settings!
