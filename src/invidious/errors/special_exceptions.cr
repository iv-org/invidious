#
# This file contains special exceptions whose error page differ from the norm.
#

# InfoExceptions are for displaying information to the user.
#
# An InfoException might or might not indicate that something went wrong.
# Historically Invidious didn't differentiate between these two options, so to
# maintain previous functionality InfoExceptions do not print backtraces.
class InfoException < Exception
end

# InitialInnerTubeParseExceptions are for used to display extra information on
# the error page for debugging/research purposes.
#
class InitialInnerTubeParseException < Exception
  # temporally place holder
  def self.new(parse_exception, **kwargs)
    instance = InitialInnerTubeParseException.allocate
    instance.initialize(error_message, parse_exception)
    return instance
  end
end
