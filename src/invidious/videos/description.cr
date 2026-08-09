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

private record Run, start_index : Int32, length : Int32, kind : Symbol, data : JSON::Any

def parse_description(desc, video_id : String) : String?
  return "" if desc.nil?

  content = desc["content"].as_s
  return "" if content.empty?

  commands = desc["commandRuns"]?.try &.as_a
  attachments = desc["attachmentRuns"]?.try &.as_a

  # If no runs at all, fall back to simple escape
  if commands.nil? && attachments.nil?
    return String.build do |str|
      content_size = content.ascii_only? ? content.size : utf16_length(content)
      copy_string(str, content.each_codepoint, content_size)
    end
  end

  # Merge commandRuns and attachmentRuns sorted by startIndex
  runs = [] of Run

  if commands
    commands.each do |cmd|
      runs << Run.new(
        start_index: cmd["startIndex"].as_i,
        length: cmd["length"].as_i,
        kind: :command,
        data: cmd
      )
    end
  end

  if attachments
    attachments.each do |att|
      runs << Run.new(
        start_index: att["startIndex"].as_i,
        length: att["length"].as_i,
        kind: :attachment,
        data: att
      )
    end
  end

  runs.sort_by!(&.start_index)

  iter = content.each_codepoint
  index = 0

  return String.build do |str|
    runs.each do |run|
      cmd_start = run.start_index
      cmd_length = run.length

      # Copy the text chunk between this run and the previous if needed.
      length = cmd_start - index
      index += copy_string(str, iter, length)

      # We need to copy the run's text using the iterator
      # and the special function defined above.
      cmd_content = String.build(cmd_length) do |str2|
        copy_string(str2, iter, cmd_length)
      end

      if run.kind == :command
        # Handle link commands
        link = cmd_content
        if on_tap = run.data.dig?("onTap", "innertubeCommand")
          link = parse_link_endpoint(on_tap, cmd_content, video_id)
        end
        str << link
      elsif run.kind == :attachment
        # Handle attachment runs (emoji images)
        element = run.data["element"]?

        if element.is_a?(JSON::Any) && element["type"]?.try &.as_s == "imageType"
          image = element["image"]?

          if image.is_a?(JSON::Any)
            sources = image["sources"]?.try &.as_a

            if sources && sources[0]?
              source = sources[0]
              # Get the emoji image URL
              emoji_url = source["url"]?.try &.as_s
              # Fallback for clientResource format (badges)
              if emoji_url.nil? || emoji_url.empty?
                emoji_url = source.dig?("clientResource", "imageName").try &.as_s
              end

              if emoji_url && !emoji_url.empty?
                # Get accessibility label
                alt_text = image.dig?("accessibility", "accessibilityData", "label").try &.as_s || cmd_content

                # Build the img tag
                if emoji_url.starts_with?("http://") || emoji_url.starts_with?("https://")
                  str << %(<img alt=") << alt_text << "\" "
                  str << %(src=") << emoji_url << "\" "
                  str << %(title=") << alt_text << "\" "
                  str << %(class="channel-emoji" />)
                else
                  # For internal resource names (badges), skip rendering
                  str << cmd_content
                end
              else
                str << cmd_content
              end
            else
              str << cmd_content
            end
          else
            str << cmd_content
          end
        else
          str << cmd_content
        end
      end

      index += cmd_length
    end

    # Copy the end of the string (past the last run).
    content_size = content.ascii_only? ? content.size : utf16_length(content)
    remaining_length = content_size - index
    copy_string(str, iter, remaining_length) if remaining_length > 0
  end
end