require "duktape/runtime"

alias SigProc = Proc(Array(String), Int32, Array(String))

struct DecryptFunction
  @decrypt_function = [] of {SigProc, Int32}
  @decrypt_time = Time.monotonic

  @playerjs_decrypt_n_function = {} of String => String
  @last_decrypted_n = {id: "", n: "", dec_n: ""}

  def initialize(@use_polling = true)
  end

  def update_decrypt_function
    @decrypt_function = fetch_decrypt_function
  end

  private def fetch_decrypt_function(id = "CvFH_6DNRCY")
    document = YT_POOL.client &.get("/watch?v=#{id}&gl=US&hl=en").body
    url = document.match(/src="(?<url>\/s\/player\/[^\/]+\/player_ias[^\/]+\/en_US\/base.js)"/).not_nil!["url"]
    player = YT_POOL.client &.get(url).body

    function_name = player.match(/^(?<name>[^=]+)=function\(\w\){\w=\w\.split\(""\);[^\. ]+\.[^( ]+/m).not_nil!["name"]
    function_body = player.match(/^#{Regex.escape(function_name)}=function\(\w\){(?<body>[^}]+)}/m).not_nil!["body"]
    function_body = function_body.split(";")[1..-2]

    var_name = function_body[0][0, 2]
    var_body = player.delete("\n").match(/var #{Regex.escape(var_name)}={(?<body>(.*?))};/).not_nil!["body"]

    operations = {} of String => SigProc
    var_body.split("},").each do |operation|
      op_name = operation.match(/^[^:]+/).not_nil![0]
      op_body = operation.match(/\{[^}]+/).not_nil![0]

      case op_body
      when "{a.reverse()"
        operations[op_name] = ->(a : Array(String), b : Int32) { a.reverse }
      when "{a.splice(0,b)"
        operations[op_name] = ->(a : Array(String), b : Int32) { a.delete_at(0..(b - 1)); a }
      else
        operations[op_name] = ->(a : Array(String), b : Int32) { c = a[0]; a[0] = a[b % a.size]; a[b % a.size] = c; a }
      end
    end

    decrypt_function = [] of {SigProc, Int32}
    function_body.each do |function|
      function = function.lchop(var_name).delete("[].")

      op_name = function.match(/[^\(]+/).not_nil![0]
      value = function.match(/\(\w,(?<value>[\d]+)\)/).not_nil!["value"].to_i

      decrypt_function << {operations[op_name], value}
    end

    return decrypt_function
  end

  def decrypt_signature(fmt : Hash(String, JSON::Any))
    return "" if !fmt["s"]? || !fmt["sp"]?

    sp = fmt["sp"].as_s
    sig = fmt["s"].as_s.split("")
    if !@use_polling
      now = Time.monotonic
      if now - @decrypt_time > 60.seconds || @decrypt_function.size == 0
        @decrypt_function = fetch_decrypt_function
        @decrypt_time = Time.monotonic
      end
    end

    @decrypt_function.each do |proc, value|
      sig = proc.call(sig, value)
    end

    return "&#{sp}=#{sig.join("")}"
  end

  def overwrite_n(id : String, fmt : Hash(String, JSON::Any))
    uri = URI.parse(fmt["url"].as_s)
    params = HTTP::Params.parse(uri.query.not_nil!)
    return fmt["url"].as_s unless params["n"]?
    n = params["n"]

    function_name = "(cache #1)"
    if (@last_decrypted_n[:id] == id && @last_decrypted_n[:n] == n)
      dec_n = @last_decrypted_n[:dec_n]
    else
      document = YT_POOL.client &.get("/watch?v=#{id}&gl=US&hl=en").body
      playerjs = document.match(/src="(?<url>\/s\/player\/[^\/]+\/player_ias[^\/]+\/en_US\/base.js)"/).not_nil!["url"]
      function_name = "(cache #2)"
      function_body = @playerjs_decrypt_n_function[playerjs]?
      if (!function_body)
        player = YT_POOL.client &.get(playerjs).body
        function_name = player.match(/a\.get\("n"\)\)&&\(b=(?<nfunc>[a-zA-Z0-9]+)\(b\)/m).not_nil!["nfunc"]
        function_body = player.match(/^#{Regex.escape(function_name)}=(?<body>function\(\w\)\{.*?"enhanced_except_[^\}]+\}[^\}]+\})/m).not_nil!["body"]
        @playerjs_decrypt_n_function[playerjs] = function_body
      end
      rt = Duktape::Runtime.new do |sbx|
        sbx.eval! "var dec=#{function_body}"
      end
      dec_n = rt.call("dec", n).to_s
      @last_decrypted_n = {id: id, n: n, dec_n: dec_n}
    end

    LOGGER.debug("decrypt_n: #{id} fn = #{function_name} n = #{n} -> #{dec_n}")
    params["n"] = dec_n
    return URI.new(uri.scheme, uri.host, uri.port, uri.path, params).to_s
  end
end
