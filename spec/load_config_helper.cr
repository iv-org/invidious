require "yaml"
require "log"

abstract class Kemal::BaseLogHandler
end

require "../src/invidious/config"
require "../src/invidious/jobs/base_job"
require "../src/invidious/jobs.cr"
require "../src/invidious/user/preferences.cr"
require "../src/invidious/helpers/logger"
require "../src/invidious/helpers/utils"

CONFIG   = Config.from_yaml(File.open("config/config.example.yml"))
HMAC_KEY = CONFIG.hmac_key
