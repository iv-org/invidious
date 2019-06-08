require "logger"

class Invidious::LogHandler < Kemal::BaseLogHandler
  def initialize(@io : IO = STDOUT)
  end

  def call(context : HTTP::Server::Context)
    time = Time.utc
    call_next(context)
    elapsed_text = elapsed_text(Time.utc - time)

    @io << time << ' ' << context.response.status_code << ' ' << context.request.method << ' ' << context.request.resource << ' ' << elapsed_text << '\n'

    if @io.is_a? File
      @io.flush
    end

    context
  end

  def write(message : String)
    @io << message

    if @io.is_a? File
      @io.flush
    end
  end

  private def elapsed_text(elapsed)
    millis = elapsed.total_milliseconds
    return "#{millis.round(2)}ms" if millis >= 1

    "#{(millis * 1000).round(2)}µs"
  end
end
