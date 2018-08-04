def fetch_decrypt_function(client, id = "CvFH_6DNRCY")
  document = client.get("/watch?v=#{id}").body
  url = document.match(/src="(?<url>\/yts\/jsbin\/player-.{9}\/en_US\/base.js)"/).not_nil!["url"]
  player = client.get(url).body

  function_name = player.match(/\(b\|\|\(b="signature"\),d.set\(b,(?<name>[a-zA-Z0-9]{2})\(c\)\)\)/).not_nil!["name"]
  function_body = player.match(/#{function_name}=function\(a\){(?<body>[^}]+)}/).not_nil!["body"]
  function_body = function_body.split(";")[1..-2]

  var_name = function_body[0][0, 2]

  operations = {} of String => String
  matches = player.delete("\n").match(/var #{var_name}={(?<op1>[a-zA-Z0-9]{2}:[^}]+}),(?<op2>[a-zA-Z0-9]{2}:[^}]+}),(?<op3>[a-zA-Z0-9]{2}:[^}]+})};/).not_nil!
  3.times do |i|
    operation = matches["op#{i + 1}"]
    op_name = operation[0, 2]

    op_body = operation.match(/\{[^}]+\}/).not_nil![0]
    case op_body
    when "{a.reverse()}"
      operations[op_name] = "a"
    when "{a.splice(0,b)}"
      operations[op_name] = "b"
    else
      operations[op_name] = "c"
    end
  end

  decrypt_function = [] of {name: String, value: Int32}
  function_body.each do |function|
    function = function.lchop(var_name + ".")
    op_name = function[0, 2]

    function = function.lchop(op_name + "(a,")
    value = function.rchop(")").to_i

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
