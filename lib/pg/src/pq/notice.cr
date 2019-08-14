module PQ
  # http://www.postgresql.org/docs/current/static/protocol-error-fields.html
  struct Notice
    getter fields : Array(PQ::Frame::ErrorNoticeFrame::Field)
    getter severity : String
    getter code : String
    getter message : String

    def initialize(@fields)
      severity = ""
      code = ""
      message = ""

      fields.each do |f|
        case f.name
        when :severity
          severity = f.message
        when :code
          code = f.message
        when :message
          message = f.message
        end
      end

      @severity = severity
      @code = code
      @message = message
    end

    def to_s(io : IO)
      io << severity
      io << ":  "
      io << message
      io << '\n'
    end
  end
end
