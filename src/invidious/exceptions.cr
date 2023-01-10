# InfoExceptions are for displaying information to the user.
#
# An InfoException might or might not indicate that something went wrong.
# Historically Invidious didn't differentiate between these two options, so to
# maintain previous functionality InfoExceptions do not print backtraces.
class InfoException < Exception
end

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

# Exception threw when an element is not found.
class NotFoundException < InfoException
end

class VideoNotAvailableException < Exception
end

# Exception used to indicate that the JSON response from YT is missing
# some important informations, and that the query should be sent again.
class RetryOnceException < Exception
end
