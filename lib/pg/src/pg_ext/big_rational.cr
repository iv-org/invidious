require "big"

module PG
  struct Numeric
    # Returns a BigRational representation of the numeric. This retains all
    # precision, but requires LibGMP installed.
    def to_big_r
      return BigRational.new(0, 1) if nan? || ndigits == 0

      ten_k = BigInt.new(10_000)
      num = digits.reduce(BigInt.new(0)) { |a, i| a*ten_k + BigInt.new(i) }
      den = ten_k**(ndigits - 1 - weight)
      quot = BigRational.new(num, den)
      neg? ? -quot : quot
    end
  end

  class ResultSet
    def read(t : BigRational.class)
      read(PG::Numeric).to_big_r
    end

    def read(t : BigRational?.class)
      read(PG::Numeric?).try &.to_big_r
    end
  end
end
