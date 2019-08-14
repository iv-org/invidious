require "../pg/geo"

module PQ
  # :nodoc:
  record Param, slice : Slice(UInt8), size : Int32, format : Int16 do
    delegate to_unsafe, to: slice

    #  Internal wrapper to represent an encoded parameter

    def self.encode(val : Nil)
      binary Pointer(UInt8).null.to_slice(0), -1
    end

    def self.encode(val : Slice)
      binary val, val.size
    end

    def self.encode(val : Array)
      text encode_array(val)
    end

    def self.encode(val : Time)
      text Time::Format::RFC_3339.format(val)
    end

    def self.encode(val : PG::Geo::Point)
      text "(#{val.x},#{val.y})"
    end

    def self.encode(val : PG::Geo::Line)
      text "{#{val.a},#{val.b},#{val.c}}"
    end

    def self.encode(val : PG::Geo::Circle)
      text "<(#{val.x},#{val.y}),#{val.radius}>"
    end

    def self.encode(val : PG::Geo::LineSegment)
      text "((#{val.x1},#{val.y1}),(#{val.x2},#{val.y2}))"
    end

    def self.encode(val : PG::Geo::Box)
      text "((#{val.x1},#{val.y1}),(#{val.x2},#{val.y2}))"
    end

    def self.encode(val : PG::Geo::Path)
      if val.closed?
        encode_points "(", val.points, ")"
      else
        encode_points "[", val.points, "]"
      end
    end

    def self.encode(val : PG::Geo::Polygon)
      encode_points "(", val.points, ")"
    end

    private def self.encode_points(left, points, right)
      string = String.build do |io|
        io << left
        points.each_with_index do |point, i|
          io << "," if i > 0
          io << "(" << point.x << "," << point.y << ")"
        end
        io << right
      end

      text string
    end

    def self.encode(val)
      text val.to_s
    end

    def self.binary(slice, size)
      new slice, size, 1_i16
    end

    def self.text(string : String)
      text string.to_slice
    end

    def self.text(slice : Bytes)
      new slice, slice.size, 0_i16
    end

    def self.encode_array(array)
      String.build(array.size + 2) do |io|
        encode_array(io, array)
      end
    end

    def self.encode_array(io, value : Array)
      io << "{"
      value.join(",", io) do |item|
        encode_array(io, item)
      end
      io << "}"
    end

    def self.encode_array(io, value)
      io << value
    end

    def self.encode_array(io, value : Bool)
      io << (value ? 't' : 'f')
    end

    def self.encode_array(io, value : Bytes)
      io << '"'
      io << String.new(value).gsub(%("), %(\\"))
      io << '"'
    end

    def self.encode_array(io, value : String)
      io << '"'
      if value.ascii_only?
        special_chars = {'"'.ord.to_u8, '\\'.ord.to_u8}
        last_index = 0
        value.to_slice.each_with_index do |byte, index|
          if special_chars.includes?(byte)
            io.write value.unsafe_byte_slice(last_index, index - last_index)
            last_index = index
            io << '\\'
          end
        end

        io.write value.unsafe_byte_slice(last_index)
      else
        last_index = 0
        reader = Char::Reader.new(value)
        while reader.has_next?
          char = reader.current_char
          if {'"', '\\'}.includes?(char)
            io.write value.unsafe_byte_slice(last_index, reader.pos - last_index)
            last_index = reader.pos
            io << '\\'
          end
          reader.next_char
        end

        io.write value.unsafe_byte_slice(last_index)
      end

      io << '"'
    end
  end
end
