module PG
  module EscapeHelper
    extend self

    # `#escape_identifier` escapes a string for use as an SQL identifier, such
    # as a table, column, or function name. This is useful when a user-supplied
    # identifier might contain special characters that would otherwise not be
    # interpreted as part of the identifier by the SQL parser, or when the
    # identifier might contain upper case characters whose case should be
    # preserved.
    def escape_identifier(str)
      escape str, true
    end

    # `#escape_literal` escapes a string for use within an SQL command. This is
    # useful when inserting data values as literal constants in SQL commands.
    # Certain characters (such as quotes and backslashes) must be escaped to
    # prevent them from being interpreted specially by the SQL parser.
    # PQescapeLiteral performs this operation.
    #
    # Note that it is not necessary nor correct to do escaping when a data
    # value is passed as a separate parameter in `#exec`
    def escape_literal(str)
      escape str, false
    end

    # `#escape_literal` escapes binary data suitable for use with the BYTEA type.
    def escape_literal(slice : Slice(UInt8))
      ssize = slice.size * 2 + 4
      String.new(ssize) do |buffer|
        buffer[0] = '\''.ord.to_u8
        buffer[1] = '\\'.ord.to_u8
        buffer[2] = 'x'.ord.to_u8
        slice.hexstring(buffer + 3)
        buffer[ssize - 1] = '\''.ord.to_u8
        {ssize, ssize}
      end
    end

    # reimplimentation of PQescapeInternal
    # todo this should take into account server encoding if not utf8
    private def escape(str : String, as_ident : Bool)
      num_quotes = 0
      num_backslashes = 0
      quote_char = as_ident ? '"' : '\''

      # scan the string for characters that must be escaped
      str.each_char do |char|
        case char
        when '\\'
          num_backslashes += 1
        when quote_char
          num_quotes += 1
        end
      end

      literal_with_backslashes = (!as_ident && num_backslashes > 0)

      result_size = str.size + num_quotes + 2
      if literal_with_backslashes
        result_size += num_backslashes + 2
      end

      String.build(result_size) do |build|
        if literal_with_backslashes
          build << ' ' << 'E'
        end
        build << quote_char

        if num_backslashes == num_quotes == 0
          str.each_char { |c| build << c }
        else
          str.each_char do |c|
            case c
            when quote_char
              build << quote_char
            when '\\'
              build << '\\' unless as_ident
            end
            build << c
          end
        end

        build << quote_char
      end
    end
  end

  class Connection
    include EscapeHelper
  end
end
