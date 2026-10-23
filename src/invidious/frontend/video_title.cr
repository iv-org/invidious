require "html"
require "uri"

module Invidious::Frontend::VideoTitle
  extend self

  # Keep word-internal hashes, URL fragments and HTML entities as plain text.
  HASHTAG = /(^|[\s\p{Z}(\[{"'])#([\p{L}\p{N}_][\p{L}\p{M}\p{N}_]*)/

  def to_html(title : String) : String
    String.build do |html|
      offset = 0

      # Match the original text, not escaped entities (which may contain '#').
      title.scan(HASHTAG) do |match|
        html << HTML.escape(title.byte_slice(offset, match.byte_begin(0) - offset))
        html << HTML.escape(match[1])

        tag = match[2]
        html << %(<a href="/hashtag/) << URI.encode_www_form(tag, space_to_plus: false) << %(">#)
        html << HTML.escape(tag) << "</a>"
        offset = match.byte_end(0)
      end

      html << HTML.escape(title.byte_slice(offset, title.bytesize - offset))
    end
  end
end
