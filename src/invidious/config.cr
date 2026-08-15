struct Config
  include YAML::Serializable

  # ... (остальной код остается прежним)

  # URL to the modified source code to be easily AGPL compliant
  # Will display in the footer, next to the main source code link
  property modified_source_code_url : String? = nil

  # Connect to YouTube over 'ipv6', 'ipv4'. Will sometimes resolve fix issues with rate-limiting (see https://github.com/ytdl-org/youtube-dl/issues/21729)
  @[YAML::Field(converter: Preferences::FamilyConverter)]
  property force_resolve : Socket::Family = Socket::Family::UNSPEC

  # Port to listen for connections (overridden by command line argument)
  property port : Int32 = 3000
  # Host to bind (overridden by command line argument)
  property host_binding : String = "0.0.0.0"
  # Path and permissions to make Invidious listen on a UNIX socket instead of a TCP port
  property socket_binding : SocketBinding