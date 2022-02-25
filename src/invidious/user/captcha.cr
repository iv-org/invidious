require "openssl/hmac"

struct Invidious::User
  module Captcha
    extend self

    private TEXTCAPTCHA_URL = URI.parse("https://textcaptcha.com")

    def generate_image(key)
      second = Random::Secure.rand(12)
      second_angle = second * 30
      second = second * 5

      minute = Random::Secure.rand(12)
      minute_angle = minute * 30
      minute = minute * 5

      hour = Random::Secure.rand(12)
      hour_angle = hour * 30 + minute_angle.to_f / 12
      if hour == 0
        hour = 12
      end

      clock_svg = <<-END_SVG
      <svg viewBox="0 0 100 100" width="200px" height="200px">
      <circle cx="50" cy="50" r="45" fill="#eee" stroke="black" stroke-width="2"></circle>

      <text x="69"     y="20.091" text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 1</text>
      <text x="82.909" y="34"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 2</text>
      <text x="88"     y="53"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 3</text>
      <text x="82.909" y="72"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 4</text>
      <text x="69"     y="85.909" text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 5</text>
      <text x="50"     y="91"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 6</text>
      <text x="31"     y="85.909" text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 7</text>
      <text x="17.091" y="72"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 8</text>
      <text x="12"     y="53"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 9</text>
      <text x="17.091" y="34"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px">10</text>
      <text x="31"     y="20.091" text-anchor="middle" fill="black" font-family="Arial" font-size="10px">11</text>
      <text x="50"     y="15"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px">12</text>

      <circle cx="50" cy="50" r="3" fill="black"></circle>
      <line id="second" transform="rotate(#{second_angle}, 50, 50)" x1="50" y1="50" x2="50" y2="12" fill="black" stroke="black" stroke-width="1"></line>
      <line id="minute" transform="rotate(#{minute_angle}, 50, 50)" x1="50" y1="50" x2="50" y2="16" fill="black" stroke="black" stroke-width="2"></line>
      <line id="hour"   transform="rotate(#{hour_angle}, 50, 50)" x1="50" y1="50" x2="50" y2="24" fill="black" stroke="black" stroke-width="2"></line>
      </svg>
      END_SVG

      image = "data:image/png;base64,"
      image += Process.run(%(rsvg-convert -w 400 -h 400 -b none -f png), shell: true,
        input: IO::Memory.new(clock_svg), output: Process::Redirect::Pipe
      ) do |proc|
        Base64.strict_encode(proc.output.gets_to_end)
      end

      answer = "#{hour}:#{minute.to_s.rjust(2, '0')}:#{second.to_s.rjust(2, '0')}"
      answer = OpenSSL::HMAC.hexdigest(:sha256, key, answer)

      return {
        question: image,
        tokens:   {generate_response(answer, {":login"}, key, use_nonce: true)},
      }
    end

    def generate_text(key)
      response = make_client(TEXTCAPTCHA_URL, &.get("/github.com/iv.org/invidious.json").body)
      response = JSON.parse(response)

      tokens = response["a"].as_a.map do |answer|
        generate_response(answer.as_s, {":login"}, key, use_nonce: true)
      end

      return {
        question: response["q"].as_s,
        tokens:   tokens,
      }
    end
  end
end
