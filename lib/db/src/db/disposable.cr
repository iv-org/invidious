module DB
  # Generic module to encapsulate disposable db resources.
  module Disposable
    macro included
      @closed = false
    end

    # Closes this object.
    def close
      return if @closed
      do_close
      @closed = true
    end

    # Returns `true` if this object is closed. See `#close`.
    def closed?
      @closed
    end

    # Implementors overrides this method to perform resource cleanup
    # If an exception is raised, the resource will not be marked as closed.
    protected abstract def do_close
  end
end
