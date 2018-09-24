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
  headers["Origin"] = "http://spys.one"
  headers["Referer"] = "http://spys.one/free-proxy-list/#{country_code}/"
  headers["Content-Type"] = "application/x-www-form-urlencoded"
  body = {
    "xpp" => "5",
    "xf1" => "0",
    "xf2" => "0",
    "xf4" => "0",
    "xf5" => "1",
  }
  response = client.post("/free-proxy-list/#{country_code}/", headers, form: body)
  response = XML.parse_html(response.body)

  mapping = response.xpath_node(%q(.//body/script)).not_nil!.content
  mapping = mapping.match(/\}\('(?<p>[^']+)',\d+,\d+,'(?<x>[^']+)'/).not_nil!
  p = mapping["p"].not_nil!
  x = mapping["x"].not_nil!
  mapping = decrypt_port(p, x)

  proxies = [] of {ip: String, port: Int32, score: Float64}
  response = response.xpath_node(%q(//tr/td/table)).not_nil!
  response.xpath_nodes(%q(.//tr)).each do |node|
    if !node["onmouseover"]?
      next
    end

    ip = node.xpath_node(%q(.//td[1]/font[2])).to_s.match(/<font class="spy14">(?<address>[^<]+)</).not_nil!["address"]
    encrypted_port = node.xpath_node(%q(.//td[1]/font[2]/script)).not_nil!.content
    encrypted_port = encrypted_port.match(/<\\\/font>"\+(?<encrypted_port>[\d\D]+)\)$/).not_nil!["encrypted_port"]

    port = ""
    encrypted_port.split("+").each do |number|
      number = number.delete("()")
      left_side, right_side = number.split("^")
      result = mapping[left_side] ^ mapping[right_side]
      port = "#{port}#{result}"
    end
    port = port.to_i

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

  proxies = proxies.sort_by { |proxy| proxy[:score] }.reverse
  return proxies
end

def decrypt_port(p, x)
  x = x.split("^")
  s = {} of String => String

  60.times do |i|
    if x[i]?.try &.empty?
      s[y_func(i)] = y_func(i)
    else
      s[y_func(i)] = x[i]
    end
  end

  x = s
  p = p.gsub(/\b\w+\b/, x)

  p = p.split(";")
  p = p.map { |item| item.split("=") }

  mapping = {} of String => Int32
  p.each do |item|
    if item == [""]
      next
    end

    key = item[0]
    value = item[1]
    value = value.split("^")

    if value.size == 1
      value = value[0].to_i
    else
      left_side = value[0].to_i?
      left_side ||= mapping[value[0]]
      right_side = value[1].to_i?
      right_side ||= mapping[value[1]]

      value = left_side ^ right_side
    end

    mapping[key] = value
  end

  return mapping
end

def y_func(c)
  return (c < 60 ? "" : y_func((c/60).to_i)) + ((c = c % 60) > 35 ? ((c.to_u8 + 29).unsafe_chr) : c.to_s(36))
end
