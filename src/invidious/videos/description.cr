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

private def skip_string(iter : Iterator, count : Int) : Int
  skipped = 0
  while skipped < count
    cp = iter.next
    break if cp.is_a?(Iterator::Stop)

    skipped += cp > 0xFFFF ? 2 : 1
  end

  skipped
end

private def image_source(url : String) : String?
  uri = URI.parse(url)

  case uri.host
  when "yt3.ggpht.com", "lh3.googleusercontent.com"
    "/ggpht#{HTML.escape(uri.request_target)}"
  end
rescue
  nil
end

private def parse_attachment_run(attachment) : String?
  source = attachment.dig?("element", "type", "imageType", "image", "sources", 0)
  return if source.nil?

  url = source["url"]?.try &.as_s?
  return if url.nil?

  src = image_source(url)
  return if src.nil?

  label = attachment.dig?("properties", "accessibilityProperties", "label").try &.as_s? || ""
  escaped_label = HTML.escape(label)

  String.build do |str|
    str << %(<img alt=") << escaped_label << %(" )
    str << %(src=") << src << %(" )
    str << %(title=") << escaped_label << %(")

    if width = source["width"]?.try &.as_i?
      str << %( width=") << width << %(")
    end

    if height = source["height"]?.try &.as_i?
      str << %( height=") << height << %(")
    end

    str << %( class="channel-emoji" />)
  end
end

private def attachment_run_inside_command?(attachment, command) : Bool
  attachment_start = attachment["startIndex"].as_i
  attachment_end = attachment_start + attachment["length"].as_i
  command_start = command["startIndex"].as_i
  command_end = command_start + command["length"].as_i

  attachment_start >= command_start &&
    attachment_start < command_end &&
    attachment_end <= command_end
end

private def parse_command_run(command, nested_attachments, iter, video_id : String) : String
  command_start = command["startIndex"].as_i
  command_length = command["length"].as_i

  command_content = String.build do |command_str|
    index = 0
    nested_attachments.sort_by { |attachment| attachment["startIndex"].as_i }.each do |attachment|
      relative_start = attachment["startIndex"].as_i - command_start
      next if relative_start < index

      index += copy_string(command_str, iter, relative_start - index)
      if attachment_html = parse_attachment_run(attachment)
        command_str << attachment_html
        index += skip_string(iter, attachment["length"].as_i)
      else
        index += copy_string(command_str, iter, attachment["length"].as_i)
      end
    end

    copy_string(command_str, iter, command_length - index) if index < command_length
  end

  link = command_content
  if on_tap = command.dig?("onTap", "innertubeCommand")
    link = parse_link_endpoint(on_tap, command_content, video_id)
  end
  link
end

private def parse_description_with_attachments(content : String, commands, attachments, video_id : String) : String
  runs = [] of Tuple(Int32, Int32, String, JSON::Any)

  commands.try &.each do |command|
    runs << {command["startIndex"].as_i, command["length"].as_i, "command", command}
  end

  attachments.each do |attachment|
    next if commands.try &.any? { |command| attachment_run_inside_command?(attachment, command) }

    runs << {attachment["startIndex"].as_i, attachment["length"].as_i, "attachment", attachment}
  end

  runs.sort_by! { |run| run[0] }

  iter = content.each_codepoint
  index = 0_i32

  String.build do |str|
    runs.each do |run|
      start_index = run[0]
      length = run[1]
      next if start_index < index

      if start_index > index
        index += copy_string(str, iter, start_index - index)
      end

      case run[2]
      when "command"
        command = run[3]
        nested_attachments = attachments.select do |attachment|
          attachment_run_inside_command?(attachment, command)
        end
        str << parse_command_run(command, nested_attachments, iter, video_id)
      when "attachment"
        attachment = run[3]
        if attachment_html = parse_attachment_run(attachment)
          str << attachment_html
          skip_string(iter, length)
        else
          copy_string(str, iter, length)
        end
      end

      index += length
    end

    content_size = content.ascii_only? ? content.size : utf16_length(content)
    remaining_length = content_size - index
    copy_string(str, iter, remaining_length) if remaining_length > 0
  end
end

def parse_description(desc, video_id : String) : String?
  return "" if desc.nil?

  content = desc["content"].as_s
  return "" if content.empty?

  commands = desc["commandRuns"]?.try &.as_a
  if attachments = desc["attachmentRuns"]?.try &.as_a
    return parse_description_with_attachments(content, commands, attachments, video_id)
  end

  if commands.nil?
    # Slightly faster than HTML.escape, as we're only doing one pass on
    # the string instead of five for the standard library
    return String.build do |str|
      content_size = content.ascii_only? ? content.size : utf16_length(content)
      copy_string(str, content.each_codepoint, content_size)
    end
  end

  # Not everything is stored in UTF-8 on youtube's side. The SMP codepoints
  # (0x10000 and above) are encoded as UTF-16 surrogate pairs, which are
  # automatically decoded by the JSON parser. It means that we need to count
  # copied byte in a special manner, preventing the use of regular string copy.
  iter = content.each_codepoint

  index = 0

  return String.build do |str|
    commands.each do |command|
      cmd_start = command["startIndex"].as_i
      cmd_length = command["length"].as_i

      # Copy the text chunk between this command and the previous if needed.
      length = cmd_start - index
      index += copy_string(str, iter, length)

      # We need to copy the command's text using the iterator
      # and the special function defined above.
      cmd_content = String.build(cmd_length) do |str2|
        copy_string(str2, iter, cmd_length)
      end

      link = cmd_content
      if on_tap = command.dig?("onTap", "innertubeCommand")
        link = parse_link_endpoint(on_tap, cmd_content, video_id)
      end
      str << link
      index += cmd_length
    end

    # Copy the end of the string (past the last command).
    content_size = content.ascii_only? ? content.size : utf16_length(content)
    remaining_length = content_size - index
    copy_string(str, iter, remaining_length) if remaining_length > 0
  end
end
