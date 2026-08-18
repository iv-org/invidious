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

# Google image CDNs that the /ggpht route can serve. They share a path
# namespace, so an emoji hosted on googleusercontent is also reachable through
# the ggpht pool that route proxies to.
private EMOJI_IMAGE_DOMAINS = {"ggpht.com", "googleusercontent.com"}

# Custom emojis (channel membership ones, and the ":face-red-heart-shape:"
# set) have no unicode equivalent, so youtube sends them as an image
# attachment covering the ":shortcut:" text, which has to be rendered as an
# <img> tag, otherwise the raw shortcut is shown to the user.
#
# Standard emojis are sent as attachments too, but the content string already
# holds the real unicode character, so those are left untouched: rendering
# them as images would only add pointless requests to youtube's servers.
#
# Custom emojis are hosted on google's image CDNs, which are all reachable
# through the /ggpht route, so anything hosted elsewhere (youtube.com and
# gstatic.com serve the standard emojis) is deliberately left as text.
private def parse_emoji_attachment(attachment : JSON::Any, text : String) : String
  image = attachment.dig?("element", "type", "imageType", "image")
  return text if image.nil?

  source = image.dig?("sources", 0)
  return text if source.nil?

  url = source["url"]?.try &.as_s
  return text if url.nil?

  uri = URI.parse(url)
  host = uri.host
  return text if host.nil?

  # Matching on the bare suffix would also accept "notggpht.com", so the host
  # has to be the domain itself or one of its subdomains.
  accepted = EMOJI_IMAGE_DOMAINS.any? do |domain|
    host == domain || host.ends_with?(".#{domain}")
  end
  return text if !accepted

  properties = attachment.dig?("element", "properties")

  # The label is the emoji name, e.g "ToonThumbsUp" for ":_ToonThumbsUp:".
  # `text` was produced by copy_string, which escapes as it copies, so it is
  # only the raw label coming from youtube that still needs to be escaped.
  raw_label = properties.try(&.dig?("accessibilityProperties", "label")).try(&.as_s)
  label = raw_label.nil? ? text : HTML.escape(raw_label)

  # Youtube gives the display size in "points" here, and the intrinsic size
  # of the image in the source. The former is what the official client uses.
  width = properties.try(&.dig?("layoutProperties", "width", "value")).try(&.as_i)
  height = properties.try(&.dig?("layoutProperties", "height", "value")).try(&.as_i)
  width ||= source["width"]?.try &.as_i
  height ||= source["height"]?.try &.as_i

  return String.build do |str|
    str << %(<img alt=") << label << "\" "
    str << %(src="/ggpht) << HTML.escape(uri.request_target) << "\" "
    str << %(title=") << label << "\" "
    str << %(width=") << (width || 24) << "\" "
    str << %(height=") << (height || 24) << "\" "
    str << %(class="channel-emoji" />)
  end
end

def parse_description(desc, video_id : String) : String?
  return "" if desc.nil?

  content = desc["content"].as_s
  return "" if content.empty?

  commands = desc["commandRuns"]?.try &.as_a
  attachments = desc["attachmentRuns"]?.try &.as_a

  if commands.nil? && attachments.nil?
    # Slightly faster than HTML.escape, as we're only doing one pass on
    # the string instead of five for the standard library
    return String.build do |str|
      content_size = content.ascii_only? ? content.size : utf16_length(content)
      copy_string(str, content.each_codepoint, content_size)
    end
  end

  # Commands (links) and attachments (emojis) both index into the same string
  # and are consumed by the same iterator below, so they have to be walked in
  # a single pass, ordered by their position in the text.
  # Runs of length 0 consume nothing and come first, otherwise a command
  # sharing their index would advance past them and they'd be dropped by the
  # overlap check. Commands then come before attachments, as Crystal's sort is
  # not guaranteed to be stable.
  runs = [] of Tuple(Int32, Int32, Bool, JSON::Any)
  commands.try &.each { |cmd| runs << {cmd["startIndex"].as_i, cmd["length"].as_i, false, cmd} }
  attachments.try &.each { |att| runs << {att["startIndex"].as_i, att["length"].as_i, true, att} }
  runs.sort_by! { |run| {run[0], run[1] == 0 ? 0 : 1, run[2] ? 1 : 0} }

  # Not everything is stored in UTF-8 on youtube's side. The SMP codepoints
  # (0x10000 and above) are encoded as UTF-16 surrogate pairs, which are
  # automatically decoded by the JSON parser. It means that we need to count
  # copied byte in a special manner, preventing the use of regular string copy.
  iter = content.each_codepoint

  index = 0

  return String.build do |str|
    runs.each do |(run_start, run_length, is_attachment, node)|
      # Overlapping runs would desynchronize the iterator from the index, so
      # anything starting inside an already consumed run is skipped.
      next if run_start < index

      # Copy the text chunk between this run and the previous if needed.
      length = run_start - index
      index += copy_string(str, iter, length)

      # We need to copy the run's text using the iterator
      # and the special function defined above.
      # Attachments may have a length of 0, when youtube inserts an image
      # without any text behind it, in which case nothing is consumed.
      run_content = if run_length > 0
                      String.build(run_length) { |str2| copy_string(str2, iter, run_length) }
                    else
                      ""
                    end

      if is_attachment
        str << parse_emoji_attachment(node, run_content)
      else
        link = run_content
        if on_tap = node.dig?("onTap", "innertubeCommand")
          link = parse_link_endpoint(on_tap, run_content, video_id)
        end
        str << link
      end

      index += run_length
    end

    # Copy the end of the string (past the last run).
    content_size = content.ascii_only? ? content.size : utf16_length(content)
    remaining_length = content_size - index
    copy_string(str, iter, remaining_length) if remaining_length > 0
  end
end
