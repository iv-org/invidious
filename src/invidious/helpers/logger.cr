require "logger"

enum LogLevel
  Debug
  Info
  Warn
  Error
end

class Invidious::LogHandler < Kemal::BaseLogHandler
  def initialize(@io : IO = STDOUT, @level = LogLevel::Warn)
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

  def puts(message : String)
    @io << message << '\n'

    if @io.is_a? File
      @io.flush
    end
  end

  def write(message : String, level = @level)
    @io << message

    if @io.is_a? File
      @io.flush
    end
  end

  def set_log_level(level : String)
    case level.downcase
    when "debug"
      set_log_level(LogLevel::Debug)
    when "info"
      set_log_level(LogLevel::Info)
    when "warn"
      set_log_level(LogLevel::Warn)
    when "error"
      set_log_level(LogLevel::Error)
    end
  end

  def set_log_level(level : LogLevel)
    @level = level
  end

  {% for level in %w(debug info warn error) %}
    def {{level.id}}(message : String)
      puts(message, LogLevel::{{level.id.capitalize}})
    end
  {% end %}

  private def elapsed_text(elapsed)
    millis = elapsed.total_milliseconds
    return "#{millis.round(2)}ms" if millis >= 1

    "#{(millis * 1000).round(2)}µs"
  end
end
