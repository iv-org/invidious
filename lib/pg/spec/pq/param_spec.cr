require "spec"
require "../../src/pq/param"

private def it_encodes_array(value, encoded)
  it "encodes #{value.class}" do
    PQ::Param.encode_array(value).should eq encoded
  end
end

describe PQ::Param do
  describe "encoders" do
    describe "#encode_array" do
      it_encodes_array([] of String, "{}")
      it_encodes_array([true, false, true], "{t,f,t}")
      it_encodes_array(["t", "f", "t"], %({"t","f","t"}))
      it_encodes_array([1, 2, 3], "{1,2,3}")
      it_encodes_array([1.2, 3.4, 5.6], "{1.2,3.4,5.6}")
      it_encodes_array([%(a), %(\\b~), %(c\\"d), %(\uFF8F)], %({"a","\\\\b~","c\\\\\\"d","\uFF8F"}))
      it_encodes_array(["baz, bar"], %({"baz, bar"}))
      it_encodes_array(["foo}"], %({"foo}"}))
    end
  end
end
