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

def decode_length_seconds(string)
  length_seconds = string.gsub(/[^0-9:]/, "")
  return 0_i32 if length_seconds.empty?

  length_seconds = length_seconds.split(":").map { |x| x.to_i? || 0 }
  length_seconds = [0] * (3 - length_seconds.size) + length_seconds

  length_seconds = Time::Span.new(
    hours: length_seconds[0],
    minutes: length_seconds[1],
    seconds: length_seconds[2]
  ).total_seconds.to_i32

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

def decode_interval(string : String) : Time::Span
  rawMinutes = string.try &.to_i32?

  if !rawMinutes
    hours = /(?<hours>\d+)h/.match(string).try &.["hours"].try &.to_i32
    hours ||= 0

    minutes = /(?<minutes>\d+)m(?!s)/.match(string).try &.["minutes"].try &.to_i32
    minutes ||= 0

    time = Time::Span.new(hours: hours, minutes: minutes)
  else
    time = Time::Span.new(minutes: rawMinutes)
  end

  return time
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
    return translate_count(locale, "generic_count_years", span.total_days.to_i // 365)
  elsif span.total_days > 30.0
    return translate_count(locale, "generic_count_months", span.total_days.to_i // 30)
  elsif span.total_days > 7.0
    return translate_count(locale, "generic_count_weeks", span.total_days.to_i // 7)
  elsif span.total_hours > 24.0
    return translate_count(locale, "generic_count_days", span.total_days.to_i)
  elsif span.total_minutes > 60.0
    return translate_count(locale, "generic_count_hours", span.total_hours.to_i)
  elsif span.total_seconds > 60.0
    return translate_count(locale, "generic_count_minutes", span.total_minutes.to_i)
  else
    return translate_count(locale, "generic_count_seconds", span.total_seconds.to_i)
  end
end

def number_with_separator(number)
  number.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\\1,").reverse
end

def short_text_to_number(short_text : String) : Int64
  matches = /(?<number>\d+(\.\d+)?)\s?(?<suffix>[mMkKbB]?)/.match(short_text)
  number = matches.try &.["number"].to_f || 0.0

  case matches.try &.["suffix"].downcase
  when "k" then number *= 1_000
  when "m" then number *= 1_000_000
  when "b" then number *= 1_000_000_000
  end

  return number.to_i64
rescue ex
  return 0_i64
end

def number_to_short_text(number)
  separated = number_with_separator(number).gsub(",", ".").split("")
  text = separated.first(2).join

  if separated[2]? && separated[2] != "."
    text += separated[2]
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

def make_host_url(kemal_config)
  ssl = CONFIG.https_only || kemal_config.ssl
  port = CONFIG.external_port || kemal_config.port

  if ssl
    scheme = "https://"
  else
    scheme = "http://"
  end

  # Add if non-standard port
  if port != 80 && port != 443
    port = ":#{port}"
  else
    port = ""
  end

  if !CONFIG.domain
    return ""
  end

  host = CONFIG.domain.not_nil!.lchop(".")

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

  referer = referer.request_target
  referer = "/" + referer.gsub(/[^\/?@&%=\-_.:,0-9a-zA-Z]/, "").lstrip("/\\")

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

def subscribe_pubsub(topic, key)
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

  return make_client(PUBSUB_URL, &.post("/subscribe", form: body))
end

def parse_range(range)
  if !range
    return 0_i64, nil
  end

  ranges = range.lchop("bytes=").split(',')
  ranges.each do |r|
    start_range, end_range = r.split('-')

    start_range = start_range.to_i64? || 0_i64
    end_range = end_range.to_i64?

    return start_range, end_range
  end

  return 0_i64, nil
end

def fetch_random_instance
  begin
    instance_api_client = make_client(URI.parse("https://api.invidious.io"))

    # Timeouts
    instance_api_client.connect_timeout = 10.seconds
    instance_api_client.dns_timeout = 10.seconds

    instance_list = JSON.parse(instance_api_client.get("/instances.json").body).as_a
    instance_api_client.close
  rescue Socket::ConnectError | IO::TimeoutError | JSON::ParseException
    instance_list = [] of JSON::Any
  end

  filtered_instance_list = [] of String

  instance_list.each do |data|
    # TODO Check if current URL is onion instance and use .onion types if so.
    if data[1]["type"] == "https"
      # Instances can have statistics disabled, which is an requirement of version validation.
      # as_nil? doesn't exist. Thus we'll have to handle the error raised if as_nil fails.
      begin
        data[1]["stats"].as_nil
        next
      rescue TypeCastError
      end

      # stats endpoint could also lack the software dict.
      next if data[1]["stats"]["software"]?.nil?

      # Makes sure the instance isn't too outdated.
      if remote_version = data[1]["stats"]?.try &.["software"]?.try &.["version"]
        remote_commit_date = remote_version.as_s.match(/\d{4}\.\d{2}\.\d{2}/)
        next if !remote_commit_date

        remote_commit_date = Time.parse(remote_commit_date[0], "%Y.%m.%d", Time::Location::UTC)
        local_commit_date = Time.parse(CURRENT_VERSION, "%Y.%m.%d", Time::Location::UTC)

        next if (remote_commit_date - local_commit_date).abs.days > 30

        begin
          data[1]["monitor"].as_nil
          health = data[1]["monitor"].as_h["dailyRatios"][0].as_h["ratio"]
          filtered_instance_list << data[0].as_s if health.to_s.to_f > 90
        rescue TypeCastError
          # We can't check the health if the monitoring is broken. Thus we'll just add it to the list
          # and move on. Ideally we'll ignore any instance that has broken health monitoring but due to the fact that
          # it's an error that often occurs with all the instances at the same time, we have to just skip the check.
          filtered_instance_list << data[0].as_s
        end
      end
    end
  end

  # If for some reason no instances managed to get fetched successfully then we'll just redirect to redirect.invidious.io
  if filtered_instance_list.size == 0
    return "redirect.invidious.io"
  end

  return filtered_instance_list.sample(1)[0]
end

def reduce_uri(uri : URI | String, max_length : Int32 = 50, suffix : String = "…") : String
  str = uri.to_s.sub(/^https?:\/\//, "")
  if str.size > max_length
    str = "#{str[0, max_length]}#{suffix}"
  end
  return str
end

# Get the html link from a NavigationEndpoint or an innertubeCommand
def parse_link_endpoint(endpoint : JSON::Any, text : String, video_id : String)
  if url = endpoint.dig?("urlEndpoint", "url").try &.as_s
    url = URI.parse(url)
    displayed_url = text

    if url.host == "youtu.be"
      url = "/watch?v=#{url.request_target.lstrip('/')}"
    elsif url.host.nil? || url.host.not_nil!.ends_with?("youtube.com")
      if url.path == "/redirect"
        # Sometimes, links can be corrupted (why?) so make sure to fallback
        # nicely. See https://github.com/iv-org/invidious/issues/2682
        url = url.query_params["q"]? || ""
        displayed_url = url
      else
        url = url.request_target
        displayed_url = "youtube.com#{url}"
      end
    end

    text = %(<a href="#{url}">#{reduce_uri(displayed_url)}</a>)
  elsif watch_endpoint = endpoint.dig?("watchEndpoint")
    start_time = watch_endpoint["startTimeSeconds"]?.try &.as_i
    link_video_id = watch_endpoint["videoId"].as_s

    url = "/watch?v=#{link_video_id}"
    url += "&t=#{start_time}" if !start_time.nil?

    # If the current video ID (passed through from the caller function)
    # is the same as the video ID in the link, add HTML attributes for
    # the JS handler function that bypasses page reload.
    #
    # See: https://github.com/iv-org/invidious/issues/3063
    if link_video_id == video_id
      start_time ||= 0
      text = %(<a href="#{url}" data-onclick="jump_to_time" data-jump-time="#{start_time}">#{reduce_uri(text)}</a>)
    else
      text = %(<a href="#{url}">#{text}</a>)
    end
  elsif url = endpoint.dig?("commandMetadata", "webCommandMetadata", "url").try &.as_s
    if text.starts_with?(/\s?[@#]/)
      # Handle "pings" in comments and hasthags differently
      # See:
      #  - https://github.com/iv-org/invidious/issues/3038
      #  - https://github.com/iv-org/invidious/issues/3062
      text = %(<a href="#{url}">#{text}</a>)
    else
      text = %(<a href="#{url}">#{reduce_uri(url)}</a>)
    end
  end
  return text
end
