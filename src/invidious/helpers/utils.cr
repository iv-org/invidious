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

def make_client(url, proxies = {} of String => Array({ip: String, port: Int32}), region = nil)
  context = OpenSSL::SSL::Context::Client.new
  context.add_options(
    OpenSSL::SSL::Options::ALL |
    OpenSSL::SSL::Options::NO_SSL_V2 |
    OpenSSL::SSL::Options::NO_SSL_V3
  )
  client = HTTPClient.new(url, context)
  client.read_timeout = 10.seconds
  client.connect_timeout = 10.seconds

  if region
    proxies[region]?.try &.sample(40).each do |proxy|
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
  length_seconds = string.split(":").map { |a| a.to_i }
  length_seconds = [0] * (3 - length_seconds.size) + length_seconds
  length_seconds = Time::Span.new(length_seconds[0], length_seconds[1], length_seconds[2])
  length_seconds = length_seconds.total_seconds.to_i

  return length_seconds
end

def recode_length_seconds(time)
  if time <= 0
    return ""
  else
    time = time.seconds
    text = "#{time.minutes.to_s.rjust(2, '0')}:#{time.seconds.to_s.rjust(2, '0')}"

    if time.hours > 0
      text = "#{time.hours.to_s.rjust(2, '0')}:#{text}"
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

    time = hours * 3600 + minutes * 60 + seconds + millis / 1000
  end

  return time
end

def decode_date(string : String)
  # String matches 'YYYY'
  if string.match(/^\d{4}/)
    return Time.new(string.to_i, 1, 1)
  end

  # Try to parse as format Jul 10, 2000
  begin
    return Time.parse(string, "%b %-d, %Y", Time::Location.local)
  rescue ex
  end

  case string
  when "today"
    return Time.now
  when "yesterday"
    return Time.now - 1.day
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

  return Time.now - delta
end

def recode_date(time : Time, locale)
  span = Time.now - time

  if span.total_days > 365.0
    span = translate(locale, "`x` years", (span.total_days.to_i / 365).to_s)
  elsif span.total_days > 30.0
    span = translate(locale, "`x` months", (span.total_days.to_i / 30).to_s)
  elsif span.total_days > 7.0
    span = translate(locale, "`x` weeks", (span.total_days.to_i / 7).to_s)
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

def number_to_short_text(number)
  seperated = number_with_separator(number).gsub(",", ".").split("")
  text = seperated.first(2).join

  if seperated[2]? && seperated[2] != "."
    text += seperated[2]
  end

  text = text.rchop(".0")

  if number / 1000000 != 0
    text += "M"
  elsif number / 1000 != 0
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

  if ssl
    scheme = "https://"
  else
    scheme = "http://"
  end

  if kemal_config.port != 80 && kemal_config.port != 443
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

def get_referer(env, fallback = "/")
  referer = env.params.query["referer"]?
  referer ||= env.request.headers["referer"]?
  referer ||= fallback

  referer = URI.parse(referer)

  # "Unroll" nested referrers
  loop do
    if referer.query
      params = HTTP::Params.parse(referer.query.not_nil!)
      if params["referer"]?
        referer = URI.parse(URI.unescape(params["referer"]))
      else
        break
      end
    else
      break
    end
  end

  referer = referer.full_path
  referer = "/" + referer.lstrip("\/\\")

  if referer == env.request.path
    referer = fallback
  end

  return referer
end

def read_var_int(bytes)
  num_read = 0
  result = 0

  read = bytes[num_read]

  if bytes.size == 1
    result = bytes[0].to_i32
  else
    while ((read & 0b10000000) != 0)
      read = bytes[num_read].to_u64
      value = (read & 0b01111111)
      result |= (value << (7 * num_read))

      num_read += 1
      if num_read > 5
        raise "VarInt is too big"
      end
    end
  end

  return result
end

def write_var_int(value : Int)
  bytes = [] of UInt8
  value = value.to_u32

  if value == 0
    bytes = [0_u8]
  else
    while value != 0
      temp = (value & 0b01111111).to_u8
      value = value >> 7

      if value != 0
        temp |= 0b10000000
      end

      bytes << temp
    end
  end

  return Slice.new(bytes.to_unsafe, bytes.size)
end

def sha256(text)
  digest = OpenSSL::Digest.new("SHA256")
  digest << text
  return digest.hexdigest
end
