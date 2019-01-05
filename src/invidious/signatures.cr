def fetch_decrypt_function(id = "CvFH_6DNRCY")
  client = make_client(YT_URL)
  document = client.get("/watch?v=#{id}&gl=US&hl=en&disable_polymer=1").body
  url = document.match(/src="(?<url>\/yts\/jsbin\/player_ias-.{9}\/en_US\/base.js)"/).not_nil!["url"]
  player = client.get(url).body

  function_name = player.match(/^(?<name>[^=]+)=function\(a\){a=a\.split\(""\)/m).not_nil!["name"]
  function_body = player.match(/^#{Regex.escape(function_name)}=function\(a\){(?<body>[^}]+)}/m).not_nil!["body"]
  function_body = function_body.split(";")[1..-2]

  var_name = function_body[0][0, 2]
  var_body = player.delete("\n").match(/var #{Regex.escape(var_name)}={(?<body>(.*?))};/).not_nil!["body"]

  operations = {} of String => String
  var_body.split("},").each do |operation|
    op_name = operation.match(/^[^:]+/).not_nil![0]
    op_body = operation.match(/\{[^}]+/).not_nil![0]

    case op_body
    when "{a.reverse()"
      operations[op_name] = "a"
    when "{a.splice(0,b)"
      operations[op_name] = "b"
    else
      operations[op_name] = "c"
    end
  end

  decrypt_function = [] of {name: String, value: Int32}
  function_body.each do |function|
    function = function.lchop(var_name).delete("[].")

    op_name = function.match(/[^\(]+/).not_nil![0]
    value = function.match(/\(a,(?<value>[\d]+)\)/).not_nil!["value"].to_i

    decrypt_function << {name: operations[op_name], value: value}
  end

  return decrypt_function
end

def decrypt_signature(a, code)
  a = a.split("")

  code.each do |item|
    case item[:name]
    when "a"
      a.reverse!
    when "b"
      a.delete_at(0..(item[:value] - 1))
    when "c"
      a = splice(a, item[:value])
    end
  end

  return a.join("")
end

def splice(a, b)
  c = a[0]
  a[0] = a[b % a.size]
  a[b % a.size] = c
  return a
end
