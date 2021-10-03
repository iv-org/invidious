enum LogLevel
  All   = 0
  Trace = 1
  Debug = 2
  Info  = 3
  Warn  = 4
  Error = 5
  Fatal = 6
  Off   = 7
end

class Invidious::LogHandler < Kemal::BaseLogHandler
  def initialize(@io : IO = STDOUT, @level = LogLevel::Debug)
  end

  def call(context : HTTP::Server::Context)
    elapsed_time = Time.measure { call_next(context) }
    elapsed_text = elapsed_text(elapsed_time)

    # Default: full path with parameters
    requested_url = context.request.resource

    # Try not to log search queries passed as GET parameters during normal use
    # (They will still be logged if log level is 'Debug' or 'Trace')
    if @level > LogLevel::Debug && (
         requested_url.downcase.includes?("search") || requested_url.downcase.includes?("q=")
       )
      # Log only the path
      requested_url = context.request.path
    end

    info("#{context.response.status_code} #{context.request.method} #{requested_url} #{elapsed_text}")

    context
  end

  def puts(message : String)
    @io << message << '\n'
    @io.flush
  end

  def write(message : String)
    @io << message
    @io.flush
  end

  def set_log_level(level : String)
    @level = LogLevel.parse(level)
  end

  def set_log_level(level : LogLevel)
    @level = level
  end

  {% for level in %w(trace debug info warn error fatal) %}
    def {{level.id}}(message : String)
      if LogLevel::{{level.id.capitalize}} >= @level
        puts("#{Time.utc} [{{level.id}}] #{message}")
      end
    end
  {% end %}

  private def elapsed_text(elapsed)
    millis = elapsed.total_milliseconds
    return "#{millis.round(2)}ms" if millis >= 1

    "#{(millis * 1000).round(2)}µs"
  end
end
