# Namespace for logic relating to generating WebVTT files
#
# Probably not compliant to WebVTT's specs but it is enough for Invidious.
module WebVTT
  # A WebVTT builder generates WebVTT files
  private class Builder
    # See https://developer.mozilla.org/en-US/docs/Web/API/WebVTT_API#cue_payload
    private ESCAPE_SUBSTITUTIONS = {
      '&'      => "&amp;",
      '<'      => "&lt;",
      '>'      => "&gt;",
      '\u200E' => "&lrm;",
      '\u200F' => "&rlm;",
      '\u00A0' => "&nbsp;",
    }

    def initialize(@io : IO)
    end

    # Writes an vtt cue with the specified time stamp and contents
    def cue(start_time : Time::Span, end_time : Time::Span, text : String)
      timestamp(start_time, end_time)
      @io << self.escape(text)
      @io << "\n\n"
    end

    private def timestamp(start_time : Time::Span, end_time : Time::Span)
      timestamp_component(start_time)
      @io << " --> "
      timestamp_component(end_time)

      @io << '\n'
    end

    private def timestamp_component(timestamp : Time::Span)
      @io << timestamp.hours.to_s.rjust(2, '0')
      @io << ':' << timestamp.minutes.to_s.rjust(2, '0')
      @io << ':' << timestamp.seconds.to_s.rjust(2, '0')
      @io << '.' << timestamp.milliseconds.to_s.rjust(3, '0')
    end

    private def escape(text : String) : String
      return text.gsub(ESCAPE_SUBSTITUTIONS)
    end

    def document(setting_fields : Hash(String, String)? = nil, &)
      @io << "WEBVTT\n"

      if setting_fields
        setting_fields.each do |name, value|
          @io << name << ": " << value << '\n'
        end
      end

      @io << '\n'

      yield
    end
  end

  # Returns the resulting `String` of writing WebVTT to the yielded `WebVTT::Builder`
  #
  # ```
  # string = WebVTT.build do |vtt|
  #   vtt.cue(Time::Span.new(seconds: 1), Time::Span.new(seconds: 2), "Line 1")
  #   vtt.cue(Time::Span.new(seconds: 2), Time::Span.new(seconds: 3), "Line 2")
  # end
  #
  # string # => "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nLine 1\n\n00:00:02.000 --> 00:00:03.000\nLine 2\n\n"
  # ```
  #
  # Accepts an optional settings fields hash to add settings attribute to the resulting vtt file.
  def self.build(setting_fields : Hash(String, String)? = nil, &)
    String.build do |str|
      builder = Builder.new(str)
      builder.document(setting_fields) do
        yield builder
      end
    end
  end
end
