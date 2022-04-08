# Exception used to hold the bogus UCID during a channel search.
class ChannelSearchException < InfoException
  getter channel : String

  def initialize(@channel)
  end
end

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
