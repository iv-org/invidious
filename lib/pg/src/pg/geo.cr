module PG::Geo
  record Point, x : Float64, y : Float64
  record Line, a : Float64, b : Float64, c : Float64
  record Circle, x : Float64, y : Float64, radius : Float64
  record LineSegment, x1 : Float64, y1 : Float64, x2 : Float64, y2 : Float64
  record Box, x1 : Float64, y1 : Float64, x2 : Float64, y2 : Float64

  struct Path
    getter points
    getter? closed

    def initialize(@points : Array(Point), @closed : Bool)
    end

    def open?
      !closed?
    end
  end

  record Polygon, points : Array(Point)
end
