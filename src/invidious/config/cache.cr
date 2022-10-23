require "../cache/store_type"

module Invidious::Config
  struct CacheConfig
    include YAML::Serializable

    @[YAML::Field(converter: IV::Config::URIConverter)]
    property url : URI? = URI.new

    # Required because of YAML serialization
    def initialize
    end
  end
end
