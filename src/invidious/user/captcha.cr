require "openssl/hmac"

struct Invidious::User
  struct Captcha
    private TEXTCAPTCHA_URL = URI.parse("https://textcaptcha.com")

    # Structure that holds the type, the question string and the
    # cryptographically signed response(s).
    getter type : Type
    getter question : String
    getter tokens : Array(String)

    def initialize(@type, @question, @tokens)
    end

    # -------------------
    #  Type parsing
    # -------------------

    enum Type
      None
      Text
      Image
    end

    def self.parse_type(params : HTTP::Params) : Type
      if CONFIG.captcha_enabled
        type_text = params["captcha"]? || "image"
        type = Type.parse?(type_text) || Type::Image

        # You opened the dev tools, didn't you? :P
        type = Type::Image if type.none?
      else
        type = Type::None
      end

      return type
    end

    # -------------------
    #  Generators
    # -------------------

    # High-level method that calls the captcha generator for the given type.
    def self.generate(type : Type) : Captcha?
      case type
      when .image? then return gen_image_captcha(HMAC_KEY)
      when .text?  then return gen_text_captcha(HMAC_KEY)
      else
        return nil
      end
    end

    private def self.gen_image_captcha(key) : Captcha
      second = Random::Secure.rand(12)
      second_angle = second * 30
      second = second * 5

      minute = Random::Secure.rand(12)
      minute_angle = minute * 30
      minute = minute * 5

      hour = Random::Secure.rand(12)
      hour_angle = hour * 30 + minute_angle.to_f / 12

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

      answer_raw = self.format_time(hour, minute, second, validate: false)
      answer = OpenSSL::HMAC.hexdigest(:sha256, key, answer_raw)

      LOGGER.trace("Captcha: image question is #{answer_raw} (anwser digest: #{answer})")

      return Captcha.new(
        type: Type::Image,
        question: image,
        tokens: [generate_response(answer, {":login"}, key, use_nonce: true)],
      )
    end

    private def self.format_time(hours : Int, minutes : Int, seconds : Int, *, validate : Bool)
      # Check for incorrect answers
      if validate
        raise Exception.new if !(0..23).includes?(hours)
        raise Exception.new if !(0..59).includes?(minutes)
        raise Exception.new if !(0..59).includes?(seconds)
      end

      # Normalize hours
      case hours
      when .zero? then hours = 12
      when .> 12  then hours -= 12
      end

      # Craft answer string
      return String.build(8) do |answer|
        answer << hours.to_s(precision: 2)
        answer << ':'
        answer << minutes.to_s(precision: 2)
        answer << ':'
        answer << seconds.to_s(precision: 2)
      end
    end

    private def self.gen_text_captcha(key) : Captcha
      response = make_client(TEXTCAPTCHA_URL, &.get("/github.com/iv.org/invidious.json").body)
      response = JSON.parse(response)

      tokens = response["a"].as_a.map do |answer|
        generate_response(answer.as_s, {":login"}, key, use_nonce: true)
      end

      question = response["q"].as_s

      LOGGER.trace("Captcha: text question is #{question}: (answers digests: #{tokens})")

      return Captcha.new(
        type: Type::Text,
        question: question,
        tokens: tokens,
      )
    end

    # -------------------
    #  Validation
    # -------------------

    # Return true if the captcha was succesfully validated
    # Otherwise, raise the appropriate Exception
    def self.verify(env) : Bool
      captcha_type = self.parse_type(env.params.body)

      answer = env.params.body["answer"]? || ""
      tokens = env.params.body.fetch_all("token")

      if answer.empty? || tokens.empty?
        LOGGER.debug("Captcha: validate: got error_invalid_captcha, answer or token is empty")
        raise InfoException.new("error_invalid_captcha")
      end

      case captcha_type
      when .image?
        begin
          hours, minutes, seconds = answer.split(':').map &.to_i
          answer = self.format_time(hours, minutes, seconds, validate: true)
        rescue ex
          LOGGER.debug("Captcha: validate: got error_invalid_captcha, answer to image captcha failed to parse")
          raise InfoException.new("error_invalid_captcha")
        end

        answer = OpenSSL::HMAC.hexdigest(:sha256, HMAC_KEY, answer)

        # Raises on error
        validate_request(tokens[0], answer, env.request, HMAC_KEY)
        return true
      when .text?
        answer = Digest::MD5.hexdigest(answer.downcase.strip)

        error_exception = InfoException.new

        tokens.each do |tok|
          begin
            # Raises on error
            validate_request(tok, answer, env.request, HMAC_KEY)
            return true
          rescue ex
            error_exception = ex
          end
        end

        LOGGER.debug("Captcha: validate: bad answer to text captcha")
        raise error_exception
      end

      # Just to be safe
      return false
    end
  end
end
