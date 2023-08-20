# Namespace for methods and objects relating to chapters
module Invidious::Videos::Chapters
  record Chapter, start_ms : Int32, end_ms : Int32, title : String, thumbnails : Array(Hash(String, Int32 | String))

  # Parse raw chapters data into an array of Chapter structs
  #
  # Requires the length of the video the chapters are associated to in order to construct correct ending time
  def self.parse(chapters : Array(JSON::Any), video_length_seconds : Int32)
    video_length_milliseconds = video_length_seconds.seconds.total_milliseconds

    segments = [] of Chapter

    chapters.each_with_index do |chapter, index|
      chapter = chapter["chapterRenderer"]

      title = chapter["title"]["simpleText"].as_s

      raw_thumbnails = chapter["thumbnail"]["thumbnails"].as_a
      thumbnails = [] of Hash(String, Int32 | String)

      raw_thumbnails.each do |thumbnail|
        thumbnails << {
          "url"    => thumbnail["url"].as_s,
          "width"  => thumbnail["width"].as_i,
          "height" => thumbnail["height"].as_i,
        }
      end

      start_ms = chapter["timeRangeStartMillis"].as_i

      # To get the ending range we have to peek at the next chapter.
      # If we're the last chapter then we need to calculate the end time through the video length.
      if next_chapter = chapters[index + 1]?
        end_ms = next_chapter["chapterRenderer"]["timeRangeStartMillis"].as_i
      else
        end_ms = video_length_milliseconds.to_i
      end

      segments << Chapter.new(
        start_ms: start_ms,
        end_ms: end_ms,
        title: title,
        thumbnails: thumbnails,
      )
    end

    return segments
  end
end
