# See https://github.com/crystal-lang/crystal/issues/2963
class HTTPProxy
  getter proxy_host : String
  getter proxy_port : Int32
  getter options : Hash(Symbol, String)
  getter tls : OpenSSL::SSL::Context::Client?

  def initialize(@proxy_host, @proxy_port = 80, @options = {} of Symbol => String)
  end

  def open(host, port, tls = nil, connection_options = {} of Symbol => Float64 | Nil)
    dns_timeout = connection_options.fetch(:dns_timeout, nil)
    connect_timeout = connection_options.fetch(:connect_timeout, nil)
    read_timeout = connection_options.fetch(:read_timeout, nil)

    socket = TCPSocket.new @proxy_host, @proxy_port, dns_timeout, connect_timeout
    socket.read_timeout = read_timeout if read_timeout
    socket.sync = true

    socket << "CONNECT #{host}:#{port} HTTP/1.1\r\n"

    if options[:user]?
      credentials = Base64.strict_encode("#{options[:user]}:#{options[:password]}")
      credentials = "#{credentials}\n".gsub(/\s/, "")
      socket << "Proxy-Authorization: Basic #{credentials}\r\n"
    end

    socket << "\r\n"

    resp = parse_response(socket)

    if resp[:code]? == 200
      {% if !flag?(:without_openssl) %}
        if tls
          tls_socket = OpenSSL::SSL::Socket::Client.new(socket, context: tls, sync_close: true, hostname: host)
          socket = tls_socket
        end
      {% end %}

      return socket
    else
      socket.close
      raise IO::Error.new(resp.inspect)
    end
  end

  private def parse_response(socket)
    resp = {} of Symbol => Int32 | String | Hash(String, String)

    begin
      version, code, reason = socket.gets.as(String).chomp.split(/ /, 3)

      headers = {} of String => String

      while (line = socket.gets.as(String)) && (line.chomp != "")
        name, value = line.split(/:/, 2)
        headers[name.strip] = value.strip
      end

      resp[:version] = version
      resp[:code] = code.to_i
      resp[:reason] = reason
      resp[:headers] = headers
    rescue
    end

    return resp
  end
end

class HTTPClient < HTTP::Client
  def set_proxy(proxy : HTTPProxy)
    begin
      @socket = proxy.open(host: @host, port: @port, tls: @tls, connection_options: proxy_connection_options)
    rescue IO::Error
      @socket = nil
    end
  end

  def proxy_connection_options
    opts = {} of Symbol => Float64 | Nil

    opts[:dns_timeout] = @dns_timeout
    opts[:connect_timeout] = @connect_timeout
    opts[:read_timeout] = @read_timeout

    return opts
  end
end

def get_proxies(country_code = "US")
  client = HTTP::Client.new(URI.parse("http://spys.one"))
  client.read_timeout = 10.seconds
  client.connect_timeout = 10.seconds

  headers = HTTP::Headers.new
  headers["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36"
  headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"
  headers["Accept-Language"] = "Accept-Language: en-US,en;q=0.9"
  headers["Host"] = "spys.one"
  headers["Content-Type"] = "application/x-www-form-urlencoded"
  body = {
    "xpp" => "2",
    "xf1" => "0",
    "xf2" => "2",
    "xf4" => "1",
    "xf5" => "1",
  }
  response = client.post("/free-proxy-list/#{country_code}/", headers, form: body)
  response = XML.parse_html(response.body)

  proxies = [] of {ip: String, port: Int32, score: Float64}
  response = response.xpath_nodes(%q(//table))[1]
  response.xpath_nodes(%q(.//tr)).each do |node|
    if !node["onmouseover"]?
      next
    end

    ip = node.xpath_node(%q(.//td[1]/font[2])).to_s.match(/<font class="spy14">(?<address>[^<]+)</).not_nil!["address"]
    port = 3128

    latency = node.xpath_node(%q(.//td[6])).not_nil!.content.to_f
    speed = node.xpath_node(%q(.//td[7]/font/table)).not_nil!["width"].to_f
    uptime = node.xpath_node(%q(.//td[8]/font/acronym)).not_nil!

    # Skip proxies that are down
    if uptime["title"].ends_with? "?"
      next
    end

    if md = uptime.content.match(/^\d+/)
      uptime = md[0].to_f
    else
      next
    end

    score = (uptime*4 + speed*2 + latency)/7

    proxies << {ip: ip, port: port, score: score}
  end

  return proxies
end
