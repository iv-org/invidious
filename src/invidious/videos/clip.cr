require "json"

# returns start_time, end_time and clip_title
def parse_clip_parameters(params) : {Float64, Float64, String}
  decoded_protobuf = params.try { |i| URI.decode_www_form(i) }
    .try { |i| Base64.decode(i) }
    .try { |i| IO::Memory.new(i) }
    .try { |i| Protodec::Any.parse(i) }

  start_time = decoded_protobuf
    .try(&.["50:0:embedded"]["2:1:varint"].as_i64)

  end_time = decoded_protobuf
    .try(&.["50:0:embedded"]["3:2:varint"].as_i64)

  clip_title = decoded_protobuf
    .try(&.["50:0:embedded"]["4:3:string"].as_s)

  return (start_time / 1000), (end_time / 1000), clip_title
end
