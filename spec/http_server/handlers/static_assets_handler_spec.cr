# Due to the way that specs are handled this file cannot be run together with
# everything else without causing a compile time error that'll be incredibly
# annoying to resolve.
#
# TODO: Create different spec categories that can then be ran through make.
#       An implementation of this can be seen with the tests for the Crystal compiler itself.
#
# For now run this with `crystal spec spec/http_server/handlers/static_assets_handler_spec.cr -Drunning_by_self`

{% skip_file if compare_versions(Crystal::VERSION, "1.17.0-dev") < 0 || !flag?(:running_by_self) %}

require "http"
require "spectator"
require "../../../src/invidious/http_server/static_assets_handler.cr"

private def get_static_assets_handler
  return Invidious::HttpServer::StaticAssetsHandler.new "spec/http_server/handlers/static_assets_handler", directory_listing: false
end

# Slightly modified version of `handle` function from
#
# https://github.com/crystal-lang/crystal/blob/3f369d2c721e9462d9f6126cb0bcd4c6992f0225/spec/std/http/server/handlers/static_file_handler_spec.cr#L5

private def handle(request, handler : HTTP::Handler? = nil, decompress : Bool = false)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)

  if !handler
    handler = get_static_assets_handler
    get_static_assets_handler.call context
  else
    handler.call(context)
  end

  response.close
  io.rewind

  HTTP::Client::Response.from_io(io, decompress: decompress)
end

# Makes and yields a temporary file with the given prefix
private def make_temporary_file(prefix, contents = nil, &)
  tempfile = File.tempfile(prefix, "static_assets_handler_spec", dir: "spec/http_server/handlers/static_assets_handler")
  file_link = "/#{File.basename(tempfile.path)}"
  yield tempfile, file_link
ensure
  tempfile.try &.delete
end

# Changes the contents of the temporary file after yield
private def cycle_temporary_file_contents(temporary_file, initial, &)
  temporary_file.rewind << initial
  temporary_file.rewind.flush
  yield
  temporary_file.rewind << "something else"
  temporary_file.rewind.flush
end

# Get relative file path to a file within the static_assets_handler folder
macro get_file_path(basename)
  "spec/http_server/handlers/static_assets_handler/#{ {{ basename }} }"
end

Spectator.describe StaticAssetsHandler do
  it "Can serve a file" do
    response = handle HTTP::Request.new("GET", "/test.txt")
    expect(response.status_code).to eq(200)
    expect(response.body).to eq(File.read(get_file_path("test.txt")))
  end

  it "Can serve cached file" do
    make_temporary_file("cache_test") do |temporary_file, file_link|
      cycle_temporary_file_contents(temporary_file, "foo") do
        expect(temporary_file.rewind.gets_to_end).to eq("foo")

        # Should get cached by the first run
        response = handle HTTP::Request.new("GET", file_link)
        expect(response.status_code).to eq(200)
        expect(response.body).to eq("foo")
      end

      # Temporary file is updated after `cycle_temporary_file_contents` is called
      # but if the file is successfully cached then we'll only get the original
      # contents.
      response = handle HTTP::Request.new("GET", file_link)
      expect(response.status_code).to eq(200)
      expect(response.body).to eq("foo")
    end
  end

  it "Adds cache headers" do
    response = handle HTTP::Request.new("GET", "/test.txt")
    expect(response.headers["cache_control"]).to eq("max-age=2629800")
  end

  context "Can handle range requests" do
    it "Can serve range request" do
      headers = HTTP::Headers{"Range" => "bytes=0-2"}
      response = handle HTTP::Request.new("GET", "/test.txt", headers)

      expect(response.status_code).to eq(206)
      expect(response.headers["Content-Range"]?).to eq "bytes 0-2/11"
      expect(response.body).to eq "Hel"
    end

    it "Will cache entire file even if doing partial requests" do
      make_temporary_file("range_cache") do |temporary_file, file_link|
        cycle_temporary_file_contents(temporary_file, "Hello world") do
          handle HTTP::Request.new("GET", file_link, HTTP::Headers{"Range" => "bytes=0-2"})
        end

        # Second request shouldn't have changed
        headers = HTTP::Headers{"Range" => "bytes=3-8"}
        response = handle HTTP::Request.new("GET", file_link, headers)
        expect(response.status_code).to eq(206)
        expect(response.body).to eq "lo wor"
      end
    end
  end

  context "Is able to support compression" do
    def decompressed(string : String)
      decompressed = Compress::Gzip::Reader.open(IO::Memory.new(string)) do |gzip|
        gzip.gets_to_end
      end

      return expect(decompressed)
    end

    it "For full file requests" do
      handler = HTTP::CompressHandler.new
      handler.next = get_static_assets_handler()

      make_temporary_file("check decompression handler") do |temporary_file, file_link|
        cycle_temporary_file_contents(temporary_file, "Hello world") do
          response = handle HTTP::Request.new("GET", file_link, headers: HTTP::Headers{"Accept-Encoding" => "gzip"}), handler: handler
          expect(response.headers["Content-Encoding"]).to eq("gzip")
          decompressed(response.body).to eq("Hello world")
        end

        # Are cached requests working?
        response = handle HTTP::Request.new("GET", file_link, headers: HTTP::Headers{"Accept-Encoding" => "gzip"}), handler: handler
        expect(response.headers["Content-Encoding"]).to eq("gzip")
        decompressed(response.body).to eq("Hello world")

        # Able to retrieve non gzipped file?
        response = handle HTTP::Request.new("GET", file_link), handler: handler
        expect(response.body).to eq("Hello world")
        expect(response.headers).to_not have_key("Content-Encoding")
      end
    end

    # Inspired by the equivalent tests from upstream
    it "For partial file requests" do
      handler = HTTP::CompressHandler.new
      handler.next = get_static_assets_handler()

      make_temporary_file("check_decompression_handler_on_partial_requests") do |temporary_file, file_link|
        cycle_temporary_file_contents(temporary_file, "Hello world this is a very long string") do
          range_response_results = {
            "10-20/38" => "d this is a",
            "0-0/38"   => "H",
            "5-9/38"   => " worl",
          }

          range_request_header_value = {"10-20", "5-9", "0-0"}.join(',')
          range_response_header_value = range_response_results.keys

          response = handle HTTP::Request.new("GET", file_link, headers: HTTP::Headers{"Range" => "bytes=#{range_request_header_value}", "Accept-Encoding" => "gzip"}), handler: handler
          expect(response.headers["Content-Encoding"]).to eq("gzip")

          # Decompress response
          response = HTTP::Client::Response.new(
            status: response.status,
            headers: response.headers,
            body_io: Compress::Gzip::Reader.new(IO::Memory.new(response.body)),
          )

          count = 0
          MIME::Multipart.parse(response) do |headers, part|
            part_range = headers["Content-Range"][6..]
            expect(part_range).to be_within(range_response_header_value)
            expect(part.gets_to_end).to eq(range_response_results[part_range])
            count += 1
          end

          expect(count).to eq(3)
        end

        # Is the file cached?
        temporary_file << "Something else"
        temporary_file.flush.rewind

        response = handle HTTP::Request.new("GET", file_link, headers: HTTP::Headers{"Accept-Encoding" => "gzip"}), handler: handler
        decompressed(response.body).to eq("Hello world this is a very long string")
      end
    end
  end

  it "Will not cache additional files if the cache limit is reached" do
    5.times do |times|
      data = "a" * 1_000_000

      make_temporary_file("test cache size limit #{times}") do |temporary_file, file_link|
        cycle_temporary_file_contents(temporary_file, data) do
          response = handle HTTP::Request.new("GET", file_link)
          expect(response.status_code).to eq(200)
          expect(response.body).to eq(data)
        end

        response = handle HTTP::Request.new("GET", file_link)
        expect(response.status_code).to eq(200)
        expect(response.body).to eq(data)
      end
    end

    # Cache should be 5 mb so no more files will be cached.
    make_temporary_file("test cache size limit uncached") do |temporary_file, file_link|
      cycle_temporary_file_contents(temporary_file, "a") do
        response = handle HTTP::Request.new("GET", file_link)
        expect(response.status_code).to eq(200)
        expect(response.body).to eq("a")
      end

      response = handle HTTP::Request.new("GET", file_link)
      expect(response.status_code).to eq(200)
      expect(response.body).to_not eq("a")
    end
  end

  after_each { Invidious::HttpServer::StaticAssetsHandler.clear_cache }
end
