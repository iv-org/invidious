# Overrides for Kemal's `content_for` macro in order to keep using
# kilt as it was before Kemal v1.1.1 (Kemal PR #618).

require "kemal"
require "kilt"

macro content_for(key, file = __FILE__)
  %proc = ->() {
    __kilt_io__ = IO::Memory.new
    {{ yield }}
    __kilt_io__.to_s
  }

  CONTENT_FOR_BLOCKS[{{key}}] = Tuple.new {{file}}, %proc
  nil
end
