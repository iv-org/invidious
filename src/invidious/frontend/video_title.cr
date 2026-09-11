require "html"
require "uri"

module Invidious::Frontend::VideoTitle
  extend self

  # Match hashtags the same way description links do conceptually: a "#" that is
  # not part of a word, URL path/query fragment, or HTML entity, followed by
  # letters/digits/underscores (plus combining marks after the first character).
  HASHTAG = /(?<![\p{L}\p{M}\p{N}_&#\/=?])#[\p{L}\p{N}_][\p{L}\p{M}\p{N}_]*/

  # Escape a video title for HTML and turn hashtags into /hashtag/... links.
  def to_html(title : String) : String
    String.build do |html|
      offset = 0

      # Scan the original title so escaped entities (which contain '#') are not
      # treated as hashtags.
      title.scan(HASHTAG) do |match|
        html << HTML.escape(title.byte_slice(offset, match.byte_begin - offset))

        tag = match[0].lchop('#')
        html << %(<a href="/hashtag/)
        html << URI.encode_www_form(tag, space_to_plus: false)
        html << %(">) << HTML.escape(match[0]) << "</a>"

        offset = match.byte_end
      end

      html << HTML.escape(title.byte_slice(offset, title.bytesize - offset))
    end
  end
end
