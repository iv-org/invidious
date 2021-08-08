module YouTubeStructs
  struct Caption
    property name
    property language_code
    property base_url

    getter name : String
    getter language_code : String
    getter base_url : String

    setter name

    def initialize(@name, @language_code, @base_url)
    end
  end
end
