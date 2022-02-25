# Exception used to hold the name of the missing item
# Should be used in all parsing functions
class BrokenTubeException < Exception
  getter element : String

  def initialize(@element)
  end

  def message
    return "Missing JSON element \"#{@element}\""
  end
end
