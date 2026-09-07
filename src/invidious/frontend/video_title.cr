require "html"
require "uri"

module Invidious::Frontend::VideoTitle
  extend self

  # Keep word-internal hashes, URL fragments and HTML entities as plain text.
  HASHTAG = /(?<![\p{L}\p{M}\p{N}_&#\/])#[\p{L}\p{N}_][\p{L}\p{M}\p{N}_]*/

  def to_html(title : String) : String
    String.build do |html|
      offset = 0

      # Match the original text, not escaped entities (which may contain '#').
      title.scan(HASHTAG) do |match|
        html << HTML.escape(title.byte_slice(offset, match.byte_begin - offset))
        html << "<a href=\"/search?q=" << URI.encode_www_form(match[0]) << "\">"
        html << HTML.escape(match[0]) << "</a>"
        offset = match.byte_end
      end

      html << HTML.escape(title.byte_slice(offset, title.bytesize - offset))
    end
  end
end
