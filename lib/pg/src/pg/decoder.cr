require "json"

module PG
  alias PGValue = String | Nil | Bool | Int32 | Float32 | Float64 | Time | JSON::Any | PG::Numeric

  # :nodoc:
  module Decoders
    module Decoder
      abstract def decode(io, bytesize, oid)
      abstract def oids : Array(Int32)
      abstract def type

      macro def_oids(oids)
        OIDS = {{oids}}

        def oids : Array(Int32)
          OIDS
        end
      end

      def read(io, type)
        io.read_bytes(type, IO::ByteFormat::NetworkEndian)
      end

      def read_i16(io)
        read(io, Int16)
      end

      def read_i32(io)
        read(io, Int32)
      end

      def read_i64(io)
        read(io, Int64)
      end

      def read_u32(io)
        read(io, UInt32)
      end

      def read_u64(io)
        read(io, UInt64)
      end

      def read_f32(io)
        read(io, Float32)
      end

      def read_f64(io)
        read(io, Float64)
      end
    end

    struct StringDecoder
      include Decoder

      UUID_OID = 2950

      def_oids [
        19,       # name (internal type)
        25,       # text
        142,      # xml
        705,      # unknown
        1042,     # blchar
        1043,     # varchar
        UUID_OID, # uuid
      ]

      def decode(io, bytesize, oid)
        if oid == UUID_OID
          return decode_uuid(io, bytesize)
        end

        String.new(bytesize) do |buffer|
          io.read_fully(Slice.new(buffer, bytesize))
          {bytesize, 0}
        end
      end

      private def decode_uuid(io, bytesize)
        bytes = uninitialized UInt8[6]

        String.new(36) do |buffer|
          buffer[8] = buffer[13] = buffer[18] = buffer[23] = 45_u8

          slice = bytes.to_slice[0, 4]

          io.read_fully(slice)
          slice.hexstring(buffer + 0)

          slice = bytes.to_slice[0, 2]

          io.read_fully(slice)
          slice.hexstring(buffer + 9)

          io.read_fully(slice)
          slice.hexstring(buffer + 14)

          io.read_fully(slice)
          slice.hexstring(buffer + 19)

          slice = bytes.to_slice
          io.read_fully(slice)
          slice.hexstring(buffer + 24)

          {36, 36}
        end
      end

      def type
        String
      end
    end

    struct CharDecoder
      include Decoder

      def_oids [
        18, # "char" (internal type)
      ]

      def decode(io, bytesize, oid)
        # TODO: can be done without creating an intermediate string
        String.new(bytesize) do |buffer|
          io.read_fully(Slice.new(buffer, bytesize))
          {bytesize, 0}
        end[0]
      end

      def type
        Char
      end
    end

    struct BoolDecoder
      include Decoder

      OIDS = [
        16, # bool
      ]

      def decode(io, bytesize, oid)
        case byte = io.read_byte
        when 0
          false
        when 1
          true
        else
          raise "bad boolean decode: #{byte}"
        end
      end

      def oids : Array(Int32)
        OIDS
      end

      def type
        Bool
      end
    end

    struct Int16Decoder
      include Decoder

      def_oids [
        21, # int2 (smallint)
      ]

      def decode(io, bytesize, oid)
        read_i16(io)
      end

      def type
        Int16
      end
    end

    struct Int32Decoder
      include Decoder

      def_oids [
        23,   # int4 (integer)
        2206, # regtype
      ]

      def decode(io, bytesize, oid)
        read_i32(io)
      end

      def type
        Int32
      end
    end

    struct Int64Decoder
      include Decoder

      def_oids [
        20, # int8 (bigint)
      ]

      def decode(io, bytesize, oid)
        read_u64(io).to_i64
      end

      def type
        Int64
      end
    end

    struct UIntDecoder
      include Decoder

      def_oids [
        26, # oid (internal type)
      ]

      def decode(io, bytesize, oid)
        read_u32(io)
      end

      def type
        UInt32
      end
    end

    struct Float32Decoder
      include Decoder

      def_oids [
        700, # float4
      ]

      def decode(io, bytesize, oid)
        read_f32(io)
      end

      def type
        Float32
      end
    end

    struct Float64Decoder
      include Decoder

      def_oids [
        701, # float8
      ]

      def decode(io, bytesize, oid)
        read_f64(io)
      end

      def type
        Float64
      end
    end

    struct PointDecoder
      include Decoder

      def_oids [
        600, # point
      ]

      def decode(io, bytesize, oid)
        Geo::Point.new(read_f64(io), read_f64(io))
      end

      def type
        Geo::Point
      end
    end

    struct PathDecoder
      include Decoder

      def_oids [
        602, # path
      ]

      def decode(io, bytesize, oid)
        byte = io.read_byte.not_nil!
        closed = byte == 1_u8
        Geo::Path.new(PolygonDecoder.new.decode(io, bytesize - 1, oid).points, closed)
      end

      def type
        Geo::Path
      end
    end

    struct PolygonDecoder
      include Decoder

      def_oids [
        604, # polygon
      ]

      def decode(io, bytesize, oid)
        c = read_u32(io)
        count = (pointerof(c).as(Int32*)).value
        points = Array.new(count) do |i|
          PointDecoder.new.decode(io, 16, oid)
        end
        Geo::Polygon.new(points)
      end

      def type
        Geo::Polygon
      end
    end

    struct BoxDecoder
      include Decoder

      def_oids [
        603, # box
      ]

      def decode(io, bytesize, oid)
        x2, y2, x1, y1 = read_f64(io), read_f64(io), read_f64(io), read_f64(io)
        Geo::Box.new(x1, y1, x2, y2)
      end

      def type
        Geo::Box
      end
    end

    struct LineSegmentDecoder
      include Decoder

      def_oids [
        601, # lseg
      ]

      def decode(io, bytesize, oid)
        Geo::LineSegment.new(read_f64(io), read_f64(io), read_f64(io), read_f64(io))
      end

      def type
        Geo::LineSegment
      end
    end

    struct LineDecoder
      include Decoder

      def_oids [
        628, # line
      ]

      def decode(io, bytesize, oid)
        Geo::Line.new(read_f64(io), read_f64(io), read_f64(io))
      end

      def type
        Geo::Line
      end
    end

    struct CircleDecoder
      include Decoder

      def_oids [
        718, # circle
      ]

      def decode(io, bytesize, oid)
        Geo::Circle.new(read_f64(io), read_f64(io), read_f64(io))
      end

      def type
        Geo::Circle
      end
    end

    struct JsonDecoder
      include Decoder

      JSONB_OID = 3802

      def_oids [
        114,       # json
        JSONB_OID, # jsonb
      ]

      def decode(io, bytesize, oid)
        if oid == JSONB_OID
          io.read_byte
          bytesize -= 1
        end

        string = String.new(bytesize) do |buffer|
          io.read_fully(Slice.new(buffer, bytesize))
          {bytesize, 0}
        end
        JSON.parse(string)
      end

      def type
        JSON::Any
      end
    end

    struct TimeDecoder
      include Decoder

      DATE_OID = 1082
      JAN_1_2K = Time.utc(2000, 1, 1)

      def_oids [
        DATE_OID, # date
        1114,     # timestamp
        1184,     # timestamptz
      ]

      def decode(io, bytesize, oid)
        if oid == DATE_OID
          v = read_i32(io)
          JAN_1_2K + Time::Span.new(days: v, hours: 0, minutes: 0, seconds: 0)
        else
          v = read_i64(io) # microseconds
          sec, m = v.divmod(1_000_000)
          JAN_1_2K + Time::Span.new(seconds: sec, nanoseconds: m*1000)
        end
      end

      def type
        Time
      end
    end

    struct ByteaDecoder
      include Decoder

      def_oids [
        17, # bytea
      ]

      def decode(io, bytesize, oid)
        slice = Bytes.new(bytesize)
        io.read_fully(slice)
        slice
      end

      def type
        Bytes
      end
    end

    struct NumericDecoder
      include Decoder

      def_oids [
        1700, # numeric
      ]

      def decode(io, bytesize, oid)
        ndigits = read_i16(io)
        weight = read_i16(io)
        sign = read_i16(io)
        dscale = read_i16(io)
        digits = (0...ndigits).map { |i| read_i16(io) }
        PG::Numeric.new(ndigits, weight, sign, dscale, digits)
      end

      def type
        PG::Numeric
      end
    end

    @@decoders = Hash(Int32, PG::Decoders::Decoder).new(ByteaDecoder.new)

    def self.from_oid(oid)
      @@decoders[oid]
    end

    def self.register_decoder(decoder)
      decoder.oids.each do |oid|
        @@decoders[oid] = decoder
      end
    end

    # https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.h
    register_decoder BoolDecoder.new
    register_decoder ByteaDecoder.new
    register_decoder CharDecoder.new
    register_decoder StringDecoder.new
    register_decoder Int16Decoder.new
    register_decoder Int32Decoder.new
    register_decoder Int64Decoder.new
    register_decoder UIntDecoder.new
    register_decoder JsonDecoder.new
    register_decoder Float32Decoder.new
    register_decoder Float64Decoder.new
    register_decoder TimeDecoder.new
    register_decoder NumericDecoder.new
    register_decoder PointDecoder.new
    register_decoder LineSegmentDecoder.new
    register_decoder PathDecoder.new
    register_decoder BoxDecoder.new
    register_decoder PolygonDecoder.new
    register_decoder LineDecoder.new
    register_decoder CircleDecoder.new
  end
end

require "./decoders/*"
