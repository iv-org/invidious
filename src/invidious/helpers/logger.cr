require "colorize"

module Invidious::Logger
  extend self

  def formatter(use_color : Bool = true)
    Colorize.enabled = use_color
    Colorize.on_tty_only!

    formatter = ::Log::Formatter.new do |entry, io|
      message = entry.message
      severity = entry.severity
      data = entry.data
      source = entry.source
      timestamp = entry.timestamp

      io << (use_color ? timestamp.colorize(:dark_gray) : timestamp) << " "
      io << (use_color ? colorize_severity(severity) : severity.label) << " "
      io << (use_color ? source.colorize(:dark_gray) : source) << ": " if !source.empty?
      io << message
      if !data.empty?
        io << " "
        data.each do |dat|
          io << (use_color ? dat[0].to_s.colorize(:light_cyan) : dat[0].to_s)
          io << "="
          io << dat[1].to_s
        end
      end
    end

    return formatter
  end

  private def colorize_severity(severity : Log::Severity)
    case severity
    in Log::Severity::Trace  then severity.label.colorize(:cyan)
    in Log::Severity::Info   then severity.label.colorize(:green)
    in Log::Severity::Notice then severity.label.colorize(:light_yellow)
    in Log::Severity::Warn   then severity.label.colorize(:yellow)
    in Log::Severity::Error  then severity.label.colorize(:red)
    in Log::Severity::Fatal  then severity.label.colorize(:red)
    in Log::Severity::Debug  then severity.label
    in Log::Severity::None   then severity.label
    end
  end
end

class Invidious::RequestLogHandler < Kemal::RequestLogHandler
  Log = ::Log.for(Kemal)

  def call(context : HTTP::Server::Context)
    elapsed_time = Time.measure { call_next(context) }
    elapsed_text = elapsed_text(elapsed_time)
    requested_url = context.request.resource

    # Try not to log search queries passed as GET parameters during normal use
    # (They will still be logged if log level is 'Debug' or 'Trace')
    if CONFIG.log_level > ::Log::Severity::Debug && (
         requested_url.downcase.includes?("search") || requested_url.downcase.includes?("q=")
       )
      # Log only the path
      requested_url = context.request.path
    end

    Log.info { "#{context.response.status_code} #{context.request.method} #{requested_url} #{elapsed_text}" }
    context
  end

  private def elapsed_text(elapsed)
    millis = elapsed.total_milliseconds
    return "#{millis.round(2)}ms" if millis >= 1

    "#{(millis * 1000).round(2)}µs"
  end
end
