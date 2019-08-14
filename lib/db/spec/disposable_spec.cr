require "./spec_helper"

class ADisposable
  include DB::Disposable
  @raise = false

  property raise

  protected def do_close
    raise "Unable to close" if @raise
  end
end

describe DB::Disposable do
  it "should mark as closed if able to close" do
    obj = ADisposable.new
    obj.closed?.should be_false
    obj.close
    obj.closed?.should be_true
  end

  it "should not mark as closed if unable to close" do
    obj = ADisposable.new
    obj.raise = true
    obj.closed?.should be_false
    expect_raises Exception do
      obj.close
    end
    obj.closed?.should be_false
  end
end
