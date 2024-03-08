module Invidious::Config
  module CookiesConverter
    def self.to_yaml(value : HTTP::Cookies, yaml : YAML::Nodes::Builder)
      (value.map { |c| "#{c.name}=#{c.value}" }).join("; ").to_yaml(yaml)
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : HTTP::Cookies
      unless node.is_a?(YAML::Nodes::Scalar)
        node.raise "Expected scalar, not #{node.class}"
      end

      cookies = HTTP::Cookies.new
      node.value.split(";").each do |cookie|
        next if cookie.strip.empty?
        name, value = cookie.split("=", 2)
        cookies << HTTP::Cookie.new(name.strip, value.strip)
      end

      return cookies
    end
  end

  module FamilyConverter
    def self.to_yaml(value : Socket::Family, yaml : YAML::Nodes::Builder)
      case value
      when Socket::Family::UNSPEC then yaml.scalar nil
      when Socket::Family::INET   then yaml.scalar "ipv4"
      when Socket::Family::INET6  then yaml.scalar "ipv6"
      when Socket::Family::UNIX   then raise "Invalid socket family #{value}"
      end
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Socket::Family
      if node.is_a?(YAML::Nodes::Scalar)
        case node.value.downcase
        when "ipv4" then Socket::Family::INET
        when "ipv6" then Socket::Family::INET6
        else
          Socket::Family::UNSPEC
        end
      else
        node.raise "Expected scalar, not #{node.class}"
      end
    end
  end

  module URIConverter
    def self.to_yaml(value : URI, yaml : YAML::Nodes::Builder)
      yaml.scalar value.normalize!
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : URI
      if node.is_a?(YAML::Nodes::Scalar)
        URI.parse node.value
      else
        node.raise "Expected scalar, not #{node.class}"
      end
    end
  end

  module TimeSpanConverter
    def self.to_yaml(value : Time::Span, yaml : YAML::Nodes::Builder)
      return yaml.scalar value.total_minutes.to_i32
    end

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Time::Span
      if node.is_a?(YAML::Nodes::Scalar)
        return decode_interval(node.value)
      else
        node.raise "Expected scalar, not #{node.class}"
      end
    end
  end
end
