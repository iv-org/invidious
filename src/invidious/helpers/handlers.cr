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

    if context.request.method == "HEAD" && context.request.path.ends_with? ".jpg"
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
  exclude ["/videoplayback", "/videoplayback/*", "/vi/*", "/sb/*", "/ggpht/*", "/api/v1/auth/notifications"]
  exclude ["/api/v1/auth/notifications", "/data_control"], "POST"

  def call(env)
    return call_next env if exclude_match? env

    {% if flag?(:without_zlib) %}
      call_next env
    {% else %}
      request_headers = env.request.headers

      if request_headers.includes_word?("Accept-Encoding", "gzip")
        env.response.headers["Content-Encoding"] = "gzip"
        env.response.output = Compress::Gzip::Writer.new(env.response.output, sync_close: true)
      elsif request_headers.includes_word?("Accept-Encoding", "deflate")
        env.response.headers["Content-Encoding"] = "deflate"
        env.response.output = Compress::Deflate::Writer.new(env.response.output, sync_close: true)
      end

      call_next env
    {% end %}
  end
end

class AuthHandler < Kemal::Handler
  {% for method in %w(GET POST PUT HEAD DELETE PATCH OPTIONS) %}
    only ["/api/v1/auth/*"], {{method}}
  {% end %}

  def call(env)
    return call_next env unless only_match? env

    begin
      if token = env.request.headers["Authorization"]?
        token = JSON.parse(URI.decode_www_form(token.lchop("Bearer ")))
        session = URI.decode_www_form(token["session"].as_s)
        scopes, expire, signature = validate_request(token, session, env.request, HMAC_KEY, PG_DB, nil)

        if email = PG_DB.query_one?("SELECT email FROM session_ids WHERE id = $1", session, as: String)
          user = PG_DB.query_one("SELECT * FROM users WHERE email = $1", email, as: User)
        end
      elsif sid = env.request.cookies["SID"]?.try &.value
        if sid.starts_with? "v1:"
          raise "Cannot use token as SID"
        end

        if email = PG_DB.query_one?("SELECT email FROM session_ids WHERE id = $1", sid, as: String)
          user = PG_DB.query_one("SELECT * FROM users WHERE email = $1", email, as: User)
        end

        scopes = [":*"]
        session = sid
      end

      if !user
        raise "Request must be authenticated"
      end

      env.set "scopes", scopes
      env.set "user", user
      env.set "session", session

      call_next env
    rescue ex
      env.response.content_type = "application/json"

      error_message = {"error" => ex.message}.to_json
      env.response.status_code = 403
      env.response.print error_message
    end
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

      if env.response.output.as(IO::Memory).size != 0 &&
         env.response.headers.includes_word?("Content-Type", "application/json")
        response = JSON.parse(env.response.output)

        if fields_text = env.params.query["fields"]?
          begin
            JSONFilter.filter(response, fields_text)
          rescue ex
            env.response.status_code = 400
            response = {"error" => ex.message}
          end
        end

        if env.params.query["pretty"]?.try &.== "1"
          response = response.to_pretty_json
        else
          response = response.to_json
        end
      else
        response = env.response.output.gets_to_end
      end
    rescue ex
      env.response.content_type = "application/json" if env.response.headers.includes_word?("Content-Type", "text/html")
      env.response.status_code = 500

      if env.response.headers.includes_word?("Content-Type", "application/json")
        response = {"error" => ex.message || "Unspecified error"}

        if env.params.query["pretty"]?.try &.== "1"
          response = response.to_pretty_json
        else
          response = response.to_json
        end
      end
    ensure
      env.response.output = output
      env.response.print response

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
