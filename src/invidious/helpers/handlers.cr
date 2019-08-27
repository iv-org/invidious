module HTTP::Handler
  @@exclude_routes_tree = Radix::Tree(String).new

  macro exclude(paths, method = "GET")
      class_name = {{@type.name}}
      method_downcase = {{method.downcase}}
      class_name_method = "#{class_name}/#{method_downcase}"
      ({{paths}}).each do |path|
        @@exclude_routes_tree.add class_name_method + path, '/' + method_downcase + path
      end
    end

  def exclude_match?(env : HTTP::Server::Context)
    @@exclude_routes_tree.find(radix_path(env.request.method, env.request.path)).found?
  end

  private def radix_path(method : String, path : String)
    "#{self.class}/#{method.downcase}#{path}"
  end
end

class Kemal::RouteHandler
  {% for method in %w(GET POST PUT HEAD DELETE PATCH OPTIONS) %}
  exclude ["/api/v1/*"], {{method}}
  {% end %}

  # Processes the route if it's a match. Otherwise renders 404.
  private def process_request(context)
    raise Kemal::Exceptions::RouteNotFound.new(context) unless context.route_found?
    content = context.route.handler.call(context)

    if !Kemal.config.error_handlers.empty? && Kemal.config.error_handlers.has_key?(context.response.status_code) && exclude_match?(context)
      raise Kemal::Exceptions::CustomException.new(context)
    end

    if context.request.method == "HEAD" &&
       context.request.path.ends_with? ".jpg"
      context.response.headers["Content-Type"] = "image/jpeg"
    end

    context.response.print(content)
    context
  end
end

class Kemal::ExceptionHandler
  {% for method in %w(GET POST PUT HEAD DELETE PATCH OPTIONS) %}
  exclude ["/api/v1/*"], {{method}}
  {% end %}

  private def call_exception_with_status_code(context : HTTP::Server::Context, exception : Exception, status_code : Int32)
    return if context.response.closed?
    return if exclude_match? context

    if !Kemal.config.error_handlers.empty? && Kemal.config.error_handlers.has_key?(status_code)
      context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
      context.response.status_code = status_code
      context.response.print Kemal.config.error_handlers[status_code].call(context, exception)
      context
    end
  end
end

class FilteredCompressHandler < Kemal::Handler
  exclude ["/videoplayback", "/videoplayback/*", "/vi/*", "/ggpht/*", "/api/v1/auth/notifications"]
  exclude ["/api/v1/auth/notifications", "/data_control"], "POST"

  def call(env)
    return call_next env if exclude_match? env

    {% if flag?(:without_zlib) %}
      call_next env
    {% else %}
      request_headers = env.request.headers

      if request_headers.includes_word?("Accept-Encoding", "gzip")
        env.response.headers["Content-Encoding"] = "gzip"
        env.response.output = Gzip::Writer.new(env.response.output, sync_close: true)
      elsif request_headers.includes_word?("Accept-Encoding", "deflate")
        env.response.headers["Content-Encoding"] = "deflate"
        env.response.output = Flate::Writer.new(env.response.output, sync_close: true)
      end

      call_next env
    {% end %}
  end
end

class APIHandler < Kemal::Handler
  {% for method in %w(GET POST PUT HEAD DELETE PATCH OPTIONS) %}
  only ["/api/v1/*"], {{method}}
  {% end %}
  exclude ["/api/v1/auth/notifications"], "GET"
  exclude ["/api/v1/auth/notifications"], "POST"

  def call(env)
    return call_next env unless only_match? env

    env.response.headers["Access-Control-Allow-Origin"] = "*"

    # Since /api/v1/notifications is an event-stream, we don't want
    # to wrap the response
    return call_next env if exclude_match? env

    # Here we swap out the socket IO so we can modify the response as needed
    output = env.response.output
    env.response.output = IO::Memory.new

    begin
      call_next env

      env.response.output.rewind

      if env.response.headers.includes_word?("Content-Type", "application/json")
        response = JSON.parse(env.response.output)

        if fields_text = env.params.query["fields"]?
          begin
            JSONFilter.filter(response, fields_text)
          rescue ex
            env.response.status_code = 400
            response = {"error" => ex.message}
          end
        end

        if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
          response = response.to_pretty_json
        else
          response = response.to_json
        end
      else
        response = env.response.output.gets_to_end
      end
    rescue ex
    ensure
      env.response.output = output
      env.response.puts response

      env.response.flush
    end
  end
end

class DenyFrame < Kemal::Handler
  exclude ["/embed/*"]

  def call(env)
    return call_next env if exclude_match? env

    env.response.headers["X-Frame-Options"] = "sameorigin"
    call_next env
  end
end

# Temp fixes for https://github.com/crystal-lang/crystal/issues/7383
class HTTP::UnknownLengthContent
  def read_byte
    ensure_send_continue
    if @io.is_a?(OpenSSL::SSL::Socket::Client)
      return if @io.as(OpenSSL::SSL::Socket::Client).@in_buffer_rem.empty?
    end
    @io.read_byte
  end
end

class HTTP::Client
  private def handle_response(response)
    if @socket.is_a?(OpenSSL::SSL::Socket::Client)
      close unless response.keep_alive? || @socket.as(OpenSSL::SSL::Socket::Client).@in_buffer_rem.empty?
      if @socket.as(OpenSSL::SSL::Socket::Client).@in_buffer_rem.empty?
        @socket = nil
      end
    else
      close unless response.keep_alive?
    end

    response
  end
end

# https://github.com/will/crystal-pg/pull/171
class PG::Statement < ::DB::Statement
  protected def perform_query(args : Enumerable) : ResultSet
    params = args.map { |arg| PQ::Param.encode(arg) }
    conn = self.conn
    conn.send_parse_message(@sql)
    conn.send_bind_message params
    conn.send_describe_portal_message
    conn.send_execute_message
    conn.send_sync_message
    conn.expect_frame PQ::Frame::ParseComplete
    conn.expect_frame PQ::Frame::BindComplete
    frame = conn.read
    case frame
    when PQ::Frame::RowDescription
      fields = frame.fields
    when PQ::Frame::NoData
      fields = nil
    else
      raise "expected RowDescription or NoData, got #{frame}"
    end
    ResultSet.new(self, fields)
  rescue IO::Error
    raise DB::ConnectionLost.new(connection)
  end

  protected def perform_exec(args : Enumerable) : ::DB::ExecResult
    result = perform_query(args)
    result.each { }
    ::DB::ExecResult.new(
      rows_affected: result.rows_affected,
      last_insert_id: 0_i64 # postgres doesn't support this
    )
  rescue IO::Error
    raise DB::ConnectionLost.new(connection)
  end
end
