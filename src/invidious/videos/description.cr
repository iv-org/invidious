require "html"
require "json"
require "uri"

# size < bytesize, so we need to count the number of characters that are
# two UInt16 wide.
# Taken from: https://github.com/crystal-lang/crystal/blob/8fa7f90c091aa3757821c04ee243c7ab5f67ac20/src/string/utf16.cr#L18-L20
private def utf16_length(content : String) : Int32
  u16_size = 0
  content.each_char do |char|
    u16_size += char.ord < 0x1_0000 ? 1 : 2
  end
  u16_size
end

private def skip_string(iter : Iterator, count : Int) : Int
  skipped = 0
  while skipped < count
    cp = iter.next
    break if cp.is_a?(Iterator::Stop)

    # A codepoint from the SMP counts twice
    skipped += 1 if cp > 0xFFFF
    skipped += 1
  end

  return skipped
end

private def copy_string(str : String::Builder, iter : Iterator, count : Int) : Int
  copied = 0
  while copied < count
    cp = iter.next
    break if cp.is_a?(Iterator::Stop)

    if cp == 0x26 # Ampersand (&)
      str << "&amp;"
    elsif cp == 0x27 # Single quote (')
      str << "&#39;"
    elsif cp == 0x22 # Double quote (")
      str << "&quot;"
    elsif cp == 0x3C # Less-than (<)
      str << "&lt;"
    elsif cp == 0x3E # Greater than (>)
      str << "&gt;"
    else
      str << cp.chr
    end

    # A codepoint from the SMP counts twice
    copied += 1 if cp > 0xFFFF
    copied += 1
  end

  return copied
end

# YouTube ships custom channel emoji as an image inside an `attachmentRuns`
# entry, while `content` only holds a `:_EmojiName:` placeholder followed by
# U+25A1 padding characters. Plain unicode emoji are the opposite: they are
# already present verbatim in `content`, and their attachment run points at
# YouTube's own emoji sprite (`www.youtube.com/s/gaming/emoji/...`), which the
# `/ggpht` proxy cannot serve. Therefore only the former are substituted with
# an image tag; the latter are left as the text characters they already are.
private def attachment_run_to_html(run : JSON::Any) : String?
  image = run.dig?("element", "type", "imageType", "image")
  return if image.nil?

  sources = image["sources"].as_a?
  return if sources.nil? || sources.empty?

  image_url = sources[0]["url"].as_s?
  return if image_url.nil?

  uri = URI.parse(image_url)
  return unless uri.host.try &.ends_with?("googleusercontent.com")

  alt = run.dig?("element", "properties", "accessibilityProperties", "label")
    .try &.as_s || ""
  alt = HTML.escape(alt)

  return String.build do |str|
    str << %(<img alt=") << alt << "\" "
    str << %(src="/ggpht) << uri.request_target << "\" "
    str << %(title=") << alt << "\" "
    str << %(class="channel-emoji" />)
  end
end

def parse_description(desc, video_id : String) : String?
  return "" if desc.nil?

  content = desc["content"].as_s
  return "" if content.empty?

  # Both `commandRuns` (links, timestamps, hashtags) and `attachmentRuns`
  # (emoji) are indexed in UTF-16 code units over `content`, and the two sets
  # can be interleaved, so they have to be rendered in a single ordered pass.
  runs = [] of NamedTuple(start: Int32, length: Int32, node: JSON::Any, kind: Symbol)

  desc["commandRuns"]?.try &.as_a.try do |command_runs|
    command_runs.each do |run|
      runs << {start: run["startIndex"].as_i, length: run["length"].as_i,
               node: run, kind: :command}
    end
  end

  desc["attachmentRuns"]?.try &.as_a.try do |attachment_runs|
    attachment_runs.each do |run|
      runs << {start: run["startIndex"].as_i, length: run["length"].as_i,
               node: run, kind: :attachment}
    end
  end

  # Not everything is stored in UTF-8 on youtube's side. The SMP codepoints
  # (0x10000 and above) are encoded as UTF-16 surrogate pairs, which are
  # automatically decoded by the JSON parser. It means that we need to count
  # copied byte in a special manner, preventing the use of regular string copy.
  content_size = content.ascii_only? ? content.size : utf16_length(content)

  if runs.empty?
    # Slightly faster than HTML.escape, as we're only doing one pass on
    # the string instead of five for the standard library
    return String.build do |str|
      copy_string(str, content.each_codepoint, content_size)
    end
  end

  runs.sort_by! { |run| run[:start] }

  iter = content.each_codepoint

  index = 0
  strip_padding = false

  return String.build do |str|
    runs.each do |run|
      # Skip runs that overlap an already rendered one: consuming their span
      # again would advance the iterator past the text they cover.
      next if run[:start] < index

      # Copy the text chunk between this run and the previous one.
      chunk = String.build do |str2|
        copy_string(str2, iter, run[:start] - index)
      end

      # Drop the placeholder padding that follows a substituted channel emoji.
      if strip_padding
        chunk = chunk.sub(/\A\x{25A1}+/, "")
        strip_padding = false
      end

      str << chunk
      index = run[:start]

      case run[:kind]
      when :command
        # We need to copy the command's text using the iterator
        # and the special function defined above.
        cmd_content = String.build(run[:length]) do |str2|
          copy_string(str2, iter, run[:length])
        end

        link = cmd_content
        if on_tap = run[:node].dig?("onTap", "innertubeCommand")
          link = parse_link_endpoint(on_tap, cmd_content, video_id)
        end
        str << link
      when :attachment
        if emoji = attachment_run_to_html(run[:node])
          skip_string(iter, run[:length])
          str << emoji
          strip_padding = true
        else
          # Not a channel emoji: the span is already the emoji itself.
          copy_string(str, iter, run[:length])
        end
      end

      index += run[:length]
    end

    # Copy the end of the string (past the last run).
    chunk = String.build do |str2|
      copy_string(str2, iter, content_size - index)
    end

    if strip_padding
      chunk = chunk.sub(/\A\x{25A1}+/, "")
    end

    str << chunk
  end
end
