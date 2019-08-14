module PQ
  class ConnectionError < Exception
  end

  class PQError < Exception
    getter fields : Array(Frame::ErrorResponse::Field)

    def initialize(@fields)
      super(field_message :message)
    end

    def field_message(name)
      field = fields.find { |f| f.name == name }
      field.message if field
    end
  end
end
