#
# This file contains special exceptions whose error page differ from the norm.
#

# InfoExceptions are for displaying information to the user.
#
# An InfoException might or might not indicate that something went wrong.
# Historically Invidious didn't differentiate between these two options, so to
# maintain previous functionality InfoExceptions do not print backtraces.
class InfoException < Exception
end

# InitialInnerTubeParseExceptions are for used to display extra information on
# the error page for debugging/research purposes.
#
class InitialInnerTubeParseException < Exception
  def initialize(@endpoint : String, @client_config : String, @data : String, @status_code : Int32, @mime_type : String, @cause : Exception)
  end

  def self.new(parse_exception : Exception,
               endpoint : String,
               client_config : String,
               data : String,
               status_code : Int32,
               mime_type : String)
    instance = InitialInnerTubeParseException.allocate
    instance.initialize(endpoint, client_config, data, status_code, mime_type, cause: parse_exception)
    return instance
  end

  private def render_innertube_metadata_section(locale)
    contents = %(\n\n<details>)
    contents += %(\n<summary>InnerTube request metadata</summary>)
    contents += %(\n<p>\n)
    contents += %(\n   \n```\n)

    contents += %(Endpoint: `#{@endpoint}`\n)
    contents += %(\nClient config: ```json\n#{@client_config}\n```\n)
    contents += %(\nData: ```json\n#{@data}\n```\n)
    contents += %(\nStatus code: `#{@status_code}`\n)
    contents += %(MIME type: `#{@mime_type}`)

    contents += %(\n```)
    contents += %(\n</p>)
    contents += %(\n</details>)

    return HTML.escape(contents)
  end

  def error_template_helper(env, locale)
    env.response.content_type = "text/html"
    env.response.status_code = 500

    # HTML rendering.
    exception = @cause.not_nil!
    backtrace = github_details_backtrace("Backtrace", @cause.not_nil!.inspect_with_backtrace)
    backtrace += render_innertube_metadata_section(locale)
    error_message = rendered "error_pages/generic"

    return templated "error_pages/generic_wrapper"
  end
end
