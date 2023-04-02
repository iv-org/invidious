module Invidious::Config
  struct DBConfig
    include YAML::Serializable

    property scheme : String
    property user : String
    property password : String
    property host : String
    property port : Int32
    property dbname : String

    def to_uri
      return URI.new(
        scheme: @scheme,
        user: @user,
        password: @password,
        host: @host,
        port: @port,
        path: @dbname,
      )
    end
  end
end
