module PQ
  # :nodoc:
  class ExtendedQuery
    getter conn, query, params, fields

    def initialize(conn, query, params)
      encoded_params = params.map { |v| Param.encode(v) }
      initialize(conn, query, encoded_params)
    end

    def initialize(@conn : Connection, @query : String, @params : Array(Param))
      conn.send_parse_message query
      conn.send_bind_message params
      conn.send_describe_portal_message
      conn.send_execute_message
      conn.send_sync_message
      conn.expect_frame Frame::ParseComplete
      conn.expect_frame Frame::BindComplete

      frame = conn.read
      if frame.is_a?(Frame::RowDescription)
        @fields = frame.fields
        @has_data = true
      elsif frame.is_a?(Frame::NoData)
        @fields = [] of PQ::Field
        conn.expect_frame Frame::CommandComplete | Frame::EmptyQueryResponse
        conn.expect_frame Frame::ReadyForQuery
        @has_data = false
      else
        raise "expected RowDescription or NoData, got #{frame}"
      end
      @got_data = false
    end

    def get_data
      raise "already read data" if @got_data
      if @has_data
        conn.read_all_data_rows { |row| yield row }
        conn.expect_frame Frame::ReadyForQuery
      end
      @got_data = true
    end
  end

  # :nodoc:
  class SimpleQuery
    getter conn, query

    def initialize(@conn : Connection, @query : String)
      conn.send_query_message(query)

      # read_all_data_rows { |row| yield row }
      while !conn.read.is_a?(Frame::ReadyForQuery)
      end
    end
  end
end
