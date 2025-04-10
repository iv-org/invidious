# Mute the ClientError exception raised when a connection is flushed.
# This happends when the connection is unexpectedly closed by the client.
#
class HTTP::Server::Response
  class Output
    private def unbuffered_flush
      @io.flush
    rescue ex : IO::Error
      unbuffered_close
    end
  end
end

# TODO: Document this override
#
class PG::ResultSet
  def field(index = @column_index)
    @fields.not_nil![index]
  end
end
