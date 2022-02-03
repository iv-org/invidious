# Exception used to hold the name of the missing item
# Should be used in all parsing functions
class BrokenTubeException < InfoException
  getter element : String

  def initialize(@element)
  end
end
