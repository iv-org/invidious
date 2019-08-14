class HTTP::Server::Response
  class Output
    def close
      unless response.wrote_headers? && !response.headers.has_key?("Content-Range")
        response.content_length = @out_count
      end

      ensure_headers_written

      super
    end
  end
end
