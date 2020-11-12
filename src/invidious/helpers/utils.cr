require "lsquic"
require "pool/connection"

def add_yt_headers(request)
  request.headers["user-agent"] ||= "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.97 Safari/537.36"
  request.headers["accept-charset"] ||= "ISO-8859-1,utf-8;q=0.7,*;q=0.7"
  request.headers["accept"] ||= "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
  request.headers["accept-language"] ||= "en-us,en;q=0.5"
  return if request.resource.starts_with? "/sorry/index"
  request.headers["x-youtube-client-name"] ||= "1"
  request.headers["x-youtube-client-version"] ||= "2.20200609"
  if !CONFIG.cookies.empty?
    request.headers["cookie"] = "#{(CONFIG.cookies.map { |c| "#{c.name}=#{c.value}" }).join("; ")}; #{request.headers["cookie"]?}"
  end
end

struct QUICPool
  property! url : URI
  property! capacity : Int32
  property! timeout : Float64
  property pool : ConnectionPool(QUIC::Client)

  def initialize(url : URI, @capacity = 5, @timeout = 5.0)
    @url = url
    @pool = build_pool
  end

  def client(region = nil, &block)
    if region
      conn = make_client(url, region)
      response = yield conn
    else
      conn = pool.checkout
      begin
        response = yield conn
      rescue ex
        conn.close
        conn = QUIC::Client.new(url)
        conn.family = (url.host == "www.youtube.com") ? CONFIG.force_resolve : Socket::Family::INET
        conn.family = Socket::Family::INET if conn.family == Socket::Family::UNSPEC
        conn.before_request { |r| add_yt_headers(r) } if url.host == "www.youtube.com"
        response = yield conn
      ensure
        pool.checkin(conn)
      end
    end

    response
  end

  private def build_pool
    ConnectionPool(QUIC::Client).new(capacity: capacity, timeout: timeout) do
      conn = QUIC::Client.new(url)
      conn.family = (url.host == "www.youtube.com") ? CONFIG.force_resolve : Socket::Family::INET
      conn.family = Socket::Family::INET if conn.family == Socket::Family::UNSPEC
      conn.before_request { |r| add_yt_headers(r) } if url.host == "www.youtube.com"
      conn
    end
  end
end

# See http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
def ci_lower_bound(pos, n)
  if n == 0
    return 0.0
  end

  # z value here represents a confidence level of 0.95
  z = 1.96
  phat = 1.0*pos/n

  return (phat + z*z/(2*n) - z * Math.sqrt((phat*(1 - phat) + z*z/(4*n))/n))/(1 + z*z/n)
end

def elapsed_text(elapsed)
  millis = elapsed.total_milliseconds
  return "#{millis.round(2)}ms" if millis >= 1

  "#{(millis * 1000).round(2)}µs"
end

def make_client(url : URI, region = nil)
  # TODO: Migrate any applicable endpoints to QUIC
  client = HTTPClient.new(url, OpenSSL::SSL::Context::Client.insecure)
  client.family = (url.host == "www.youtube.com") ? CONFIG.force_resolve : Socket::Family::UNSPEC
  client.read_timeout = 10.seconds
  client.connect_timeout = 10.seconds

  if region
    PROXY_LIST[region]?.try &.sample(40).each do |proxy|
      begin
        proxy = HTTPProxy.new(proxy_host: proxy[:ip], proxy_port: proxy[:port])
        client.set_proxy(proxy)
        break
      rescue ex
      end
    end
  end

  return client
end

def decode_length_seconds(string)
  length_seconds = string.gsub(/[^0-9:]/, "").split(":").map &.to_i
  length_seconds = [0] * (3 - length_seconds.size) + length_seconds
  length_seconds = Time::Span.new hours: length_seconds[0], minutes: length_seconds[1], seconds: length_seconds[2]
  length_seconds = length_seconds.total_seconds.to_i

  return length_seconds
end

def recode_length_seconds(time)
  if time <= 0
    return ""
  else
    time = time.seconds
    text = "#{time.minutes.to_s.rjust(2, '0')}:#{time.seconds.to_s.rjust(2, '0')}"

    if time.total_hours.to_i > 0
      text = "#{time.total_hours.to_i.to_s.rjust(2, '0')}:#{text}"
    end

    text = text.lchop('0')

    return text
  end
end

def decode_time(string)
  time = string.try &.to_f?

  if !time
    hours = /(?<hours>\d+)h/.match(string).try &.["hours"].try &.to_f
    hours ||= 0

    minutes = /(?<minutes>\d+)m(?!s)/.match(string).try &.["minutes"].try &.to_f
    minutes ||= 0

    seconds = /(?<seconds>\d+)s/.match(string).try &.["seconds"].try &.to_f
    seconds ||= 0

    millis = /(?<millis>\d+)ms/.match(string).try &.["millis"].try &.to_f
    millis ||= 0

    time = hours * 3600 + minutes * 60 + seconds + millis // 1000
  end

  return time
end

def decode_date(string : String)
  # String matches 'YYYY'
  if string.match(/^\d{4}/)
    return Time.utc(string.to_i, 1, 1)
  end

  # Try to parse as format Jul 10, 2000
  begin
    return Time.parse(string, "%b %-d, %Y", Time::Location.local)
  rescue ex
  end

  case string
  when "today"
    return Time.utc
  when "yesterday"
    return Time.utc - 1.day
  else nil # Continue
  end

  # String matches format "20 hours ago", "4 months ago"...
  date = string.split(" ")[-3, 3]
  delta = date[0].to_i

  case date[1]
  when .includes? "second"
    delta = delta.seconds
  when .includes? "minute"
    delta = delta.minutes
  when .includes? "hour"
    delta = delta.hours
  when .includes? "day"
    delta = delta.days
  when .includes? "week"
    delta = delta.weeks
  when .includes? "month"
    delta = delta.months
  when .includes? "year"
    delta = delta.years
  else
    raise "Could not parse #{string}"
  end

  return Time.utc - delta
end

def recode_date(time : Time, locale)
  span = Time.utc - time

  if span.total_days > 365.0
    span = translate(locale, "`x` years", (span.total_days.to_i // 365).to_s)
  elsif span.total_days > 30.0
    span = translate(locale, "`x` months", (span.total_days.to_i // 30).to_s)
  elsif span.total_days > 7.0
    span = translate(locale, "`x` weeks", (span.total_days.to_i // 7).to_s)
  elsif span.total_hours > 24.0
    span = translate(locale, "`x` days", (span.total_days.to_i).to_s)
  elsif span.total_minutes > 60.0
    span = translate(locale, "`x` hours", (span.total_hours.to_i).to_s)
  elsif span.total_seconds > 60.0
    span = translate(locale, "`x` minutes", (span.total_minutes.to_i).to_s)
  else
    span = translate(locale, "`x` seconds", (span.total_seconds.to_i).to_s)
  end

  return span
end

def number_with_separator(number)
  number.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\\1,").reverse
end

def short_text_to_number(short_text : String) : Int32
  case short_text
  when .ends_with? "M"
    number = short_text.rstrip(" mM").to_f
    number *= 1000000
  when .ends_with? "K"
    number = short_text.rstrip(" kK").to_f
    number *= 1000
  else
    number = short_text.rstrip(" ")
  end

  number = number.to_i

  return number
end

def number_to_short_text(number)
  seperated = number_with_separator(number).gsub(",", ".").split("")
  text = seperated.first(2).join

  if seperated[2]? && seperated[2] != "."
    text += seperated[2]
  end

  text = text.rchop(".0")

  if number // 1_000_000_000 != 0
    text += "B"
  elsif number // 1_000_000 != 0
    text += "M"
  elsif number // 1000 != 0
    text += "K"
  end

  text
end

def arg_array(array, start = 1)
  if array.size == 0
    args = "NULL"
  else
    args = [] of String
    (start..array.size + start - 1).each { |i| args << "($#{i})" }
    args = args.join(",")
  end

  return args
end

def make_host_url(config, kemal_config)
  ssl = config.https_only || kemal_config.ssl
  port = config.external_port || kemal_config.port

  if ssl
    scheme = "https://"
  else
    scheme = "http://"
  end

  # Add if non-standard port
  if port != 80 && port != 443
    port = ":#{kemal_config.port}"
  else
    port = ""
  end

  if !config.domain
    return ""
  end

  host = config.domain.not_nil!.lchop(".")

  return "#{scheme}#{host}#{port}"
end

def get_referer(env, fallback = "/", unroll = true)
  referer = env.params.query["referer"]?
  referer ||= env.request.headers["referer"]?
  referer ||= fallback

  referer = URI.parse(referer)

  # "Unroll" nested referrers
  if unroll
    loop do
      if referer.query
        params = HTTP::Params.parse(referer.query.not_nil!)
        if params["referer"]?
          referer = URI.parse(URI.decode_www_form(params["referer"]))
        else
          break
        end
      else
        break
      end
    end
  end

  referer = referer.full_path
  referer = "/" + referer.gsub(/[^\/?@&%=\-_.0-9a-zA-Z]/, "").lstrip("/\\")

  if referer == env.request.path
    referer = fallback
  end

  return referer
end

def sha256(text)
  digest = OpenSSL::Digest.new("SHA256")
  digest << text
  return digest.final.hexstring
end

def subscribe_pubsub(topic, key, config)
  case topic
  when .match(/^UC[A-Za-z0-9_-]{22}$/)
    topic = "channel_id=#{topic}"
  when .match(/^(PL|LL|EC|UU|FL|UL|OLAK5uy_)[0-9A-Za-z-_]{10,}$/)
    # There's a couple missing from the above regex, namely TL and RD, which
    # don't have feeds
    topic = "playlist_id=#{topic}"
  else
    # TODO
  end

  time = Time.utc.to_unix.to_s
  nonce = Random::Secure.hex(4)
  signature = "#{time}:#{nonce}"

  body = {
    "hub.callback"      => "#{HOST_URL}/feed/webhook/v1:#{time}:#{nonce}:#{OpenSSL::HMAC.hexdigest(:sha1, key, signature)}",
    "hub.topic"         => "https://www.youtube.com/xml/feeds/videos.xml?#{topic}",
    "hub.verify"        => "async",
    "hub.mode"          => "subscribe",
    "hub.lease_seconds" => "432000",
    "hub.secret"        => key.to_s,
  }

  return make_client(PUBSUB_URL).post("/subscribe", form: body)
end

def parse_range(range)
  if !range
    return 0_i64, nil
  end

  ranges = range.lchop("bytes=").split(',')
  ranges.each do |range|
    start_range, end_range = range.split('-')

    start_range = start_range.to_i64? || 0_i64
    end_range = end_range.to_i64?

    return start_range, end_range
  end

  return 0_i64, nil
end

def convert_theme(theme)
  case theme
  when "true"
    "dark"
  when "false"
    "light"
  when "", nil
    nil
  else
    theme
  end
end
