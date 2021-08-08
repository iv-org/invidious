module YouTubeStructs
  struct Caption
    property name
    property languageCode
    property baseUrl

    getter name : String
    getter languageCode : String
    getter baseUrl : String

    setter name

    def initialize(@name, @languageCode, @baseUrl)
    end
  end
end
