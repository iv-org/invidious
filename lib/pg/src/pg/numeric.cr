module PG
  # The Postgres numeric type has arbitrary precision, and can be NaN, "not a
  # number".
  #
  # The default version of `Numeric` in this driver only has `#to_f` which
  # provides approximate conversion. To get true arbitrary precision, there is
  # an optional extension `pg_ext/big_rational`, however LibGMP must be
  # installed.
  struct Numeric
    # :nodoc:
    enum Sign
      Pos =  0x0000
      Neg =  0x4000
      Nan = -0x4000
    end

    # size of digits array
    getter ndigits : Int16

    # location of decimal point in digits array
    # can be negative for small numbers such as 0.0000001
    getter weight : Int16

    # positive, negative, or nan
    getter sign : Sign

    # number of decimal point digits shown
    # 1.10 is and 1.100 would only differ here
    getter dscale : Int16

    # array of numbers from 0-10,000 representing the numeric
    # (not an array of individual digits!)
    getter digits : Array(Int16)

    def initialize(@ndigits : Int16, @weight : Int16, sign, @dscale : Int16, @digits : Array(Int16))
      @sign = Sign.from_value(sign)
    end

    # Returns `true` if the numeric is not a number.
    def nan?
      sign == Sign::Nan
    end

    # Returns `true` if the numeric is negative.
    def neg?
      sign == Sign::Neg
    end

    # The approximate representation of the numeric as a 64-bit float.
    #
    # Very small and very large values may be inaccurate and precision will be
    # lost.
    # NaN returns `0.0`.
    def to_f : Float64
      to_f64
    end

    # ditto
    def to_f64 : Float64
      num = digits.reduce(0_u64) { |a, i| a*10_000_u64 + i.to_u64 }
      den = 10_000_f64**(ndigits - 1 - weight)
      quot = num.to_f64 / den.to_f64
      neg? ? -quot : quot
    end

    def inspect(io : IO)
      to_s(io)
    end

    def to_s(io : IO)
      if ndigits == 0
        if nan?
          io << "NaN"
        else
          io << '0'
          if dscale > 0
            io << '.'
            dscale.times { io << '0' }
          end
        end

        return
      end

      io << '-' if neg?

      pos = 0

      if weight >= 0
        io << digits[0].to_s
        pos += 1
        (1..weight).each do |idx|
          pos += 1
          str = digits[idx]?.to_s
          (4 - str.size).times { io << '0' }
          io << str
        end
      end

      return if dscale <= 0

      io << '0' if weight < 0
      io << '.'

      count = 0
      (-1 - weight).times do
        io << "0000"
        count += 4
      end

      (pos...ndigits).each do |idx|
        str = digits[idx].to_s

        (4 - str.size).times do
          io << '0'
          count += 1
        end

        if idx == ndigits - 1
          remain = (dscale + str.size) % 4
          str = str[0...remain] unless remain == 0
        end
        io << str
        count += str.size
      end

      (dscale - count).times { io << '0' }
    end
  end
end
