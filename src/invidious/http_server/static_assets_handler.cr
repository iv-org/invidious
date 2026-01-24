{% skip_file if compare_versions(Crystal::VERSION, "1.17.0-dev") < 0 %}

module Invidious::HttpServer
  class StaticAssetsHandler < HTTP::StaticFileHandler
    # In addition to storing the actual data of a file, it also implements the required
    # getters needed for the object to imitate a `File::Stat` within `StaticFileHandler`.
    #
    # Since the `File::Stat` is created once in `#call` and then passed around to the
    # rest of the class's methods, imitating the object allows us to only lookup
    # the cache hash once for every request.
    #
    private record CachedFile, data : Bytes, size : Int64, modification_time : Time do
      def directory?
        false
      end

      def file?
        true
      end
    end

    CACHE_LIMIT = 5_000_000 # 5MB
    @@current_cache_size = 0
    @@cached_files = {} of Path => CachedFile

    # Returns metadata for the requested file
    #
    # If the requested file is cached, a `CachedFile` is returned instead of a `File::Stat`.
    # This represents the metadata info of a cached file and implements all the methods of `File::Stat` that
    # is used by the `StaticAssetsHandler`.
    #
    # The `CachedFile` also stores the raw bytes of the cached file, and this method serves as the place where
    # the cached file is retrieved if it exists. Though the data will only be read in `#serve_file`
    private def file_info(expanded_path : Path)
      file_path = @public_dir.join(expanded_path.to_kind(Path::Kind.native))
      {@@cached_files[file_path]? || File.info?(file_path), file_path}
    end

    # Add "Cache-Control" header to the response
    private def add_cache_headers(response_headers : HTTP::Headers, last_modified : Time) : Nil
      super; response_headers["Cache-Control"] = "max-age=2629800"
    end

    # Serves and caches the file at the given path.
    #
    # This is an override of `serve_file` to allow serving a file from memory, and to cache it
    # it as needed.
    private def serve_file(context : HTTP::Server::Context, file_info, file_path : Path, original_file_path : Path, last_modified : Time)
      context.response.content_type = MIME.from_filename(original_file_path.to_s, "application/octet-stream")

      range_header = context.request.headers["Range"]?

      # If the file is cached we can just directly serve it
      if file_info.is_a? CachedFile
        return dispatch_serve(context, file_info.data, file_info, range_header)
      end

      # Otherwise we'll need to read from disk and cache it
      retrieve_bytes_from = IO::Memory.new
      File.open(file_path) do |file|
        # We cannot cache partial data so we'll rewind and read from the start
        if range_header
          dispatch_serve(context, file, file_info, range_header)
          IO.copy(file.rewind, retrieve_bytes_from)
        else
          context.response.output = IO::MultiWriter.new(context.response.output, retrieve_bytes_from, sync_close: true)
          dispatch_serve(context, file, file_info, range_header)
        end
      end

      flush_io_to_cache(retrieve_bytes_from, file_path, file_info)
    end

    # Writes file data to the cache
    private def flush_io_to_cache(io, file_path, file_info)
      if (@@current_cache_size += file_info.size) <= CACHE_LIMIT
        @@cached_files[file_path] = CachedFile.new(io.to_slice, file_info.size, file_info.modification_time)
      end
    end

    # Either send the file in full, or just fragments of it depending on the request
    private def dispatch_serve(context, file, file_info, range_header)
      if range_header
        # an IO is needed for `serve_file_range`
        file = file.is_a?(Bytes) ? IO::Memory.new(file, writeable: false) : file
        serve_file_range(context, file, range_header, file_info)
      else
        context.response.headers["Accept-Ranges"] = "bytes"
        serve_file_full(context, file, file_info)
      end
    end

    # If we're serving the full file right away then there's no need for an IO at all.
    private def serve_file_full(context : HTTP::Server::Context, file : Bytes, file_info)
      context.response.status = :ok
      context.response.content_length = file_info.size
      context.response.write file
    end

    # Serves segments of a file based on the `Range header`
    #
    # An override of `serve_file_range` to allow using a generic IO rather than a `File`.
    # Literally the same code as what we inherited but just with the `file` argument's type
    # being set to `IO` rather than `File`
    #
    # Can be removed once https://github.com/crystal-lang/crystal/issues/15817 is fixed.
    private def serve_file_range(context : HTTP::Server::Context, file : IO, range_header : String, file_info)
      # Paste in the body of inherited serve_file_range
      {{ @type.superclass.methods.select(&.name.==("serve_file_range"))[0].body }}
    end

    # Clear cached files.
    #
    # This is only used in the specs to clear the cache before each handler test
    def self.clear_cache
      @@current_cache_size = 0
      @@cached_files.clear
    end
  end
end
