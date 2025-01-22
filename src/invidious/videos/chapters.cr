module Invidious::Videos
  # A `Chapters` struct represents an sequence of chapters for a given video
  struct Chapters
    record Chapter, start_ms : Time::Span, end_ms : Time::Span, title : String, thumbnails : Array(Hash(String, Int32 | String))
    property? auto_generated : Bool

    def initialize(@chapters : Array(Chapter), @auto_generated : Bool)
    end

    # Constructs a chapters object from InnerTube's JSON object for chapters
    #
    # Requires the length of the video the chapters are associated to in order to construct correct ending time
    def Chapters.from_raw_chapters(raw_chapters : Array(JSON::Any), video_length : Int32, is_auto_generated : Bool = false)
      video_length_milliseconds = video_length.seconds.total_milliseconds

      parsed_chapters = [] of Chapter

      raw_chapters.each_with_index do |chapter, index|
        chapter = chapter["chapterRenderer"]

        title = chapter["title"]["simpleText"].as_s

        raw_thumbnails = chapter["thumbnail"]["thumbnails"].as_a
        thumbnails = raw_thumbnails.map do |thumbnail|
          {
            "url"    => thumbnail["url"].as_s,
            "width"  => thumbnail["width"].as_i,
            "height" => thumbnail["height"].as_i,
          }
        end

        start_ms = chapter["timeRangeStartMillis"].as_i

        # To get the ending range we have to peek at the next chapter.
        # If we're the last chapter then we need to calculate the end time through the video length.
        if next_chapter = raw_chapters[index + 1]?
          end_ms = next_chapter["chapterRenderer"]["timeRangeStartMillis"].as_i
        else
          end_ms = video_length_milliseconds.to_i
        end

        parsed_chapters << Chapter.new(
          start_ms: start_ms.milliseconds,
          end_ms: end_ms.milliseconds,
          title: title,
          thumbnails: thumbnails,
        )
      end

      return Chapters.new(parsed_chapters, is_auto_generated)
    end

    # Calls the given block for each chapter and passes it as a parameter
    def each(&)
      @chapters.each { |c| yield c }
    end

    # Converts the sequence of chapters to a WebVTT representation
    def to_vtt
      return WebVTT.build do |build|
        self.each do |chapter|
          build.cue(chapter.start_ms, chapter.end_ms, chapter.title)
        end
      end
    end

    # Dumps a JSON representation of the sequence of chapters to the given JSON::Builder
    def to_json(json : JSON::Builder)
      json.field "autoGenerated", @auto_generated.to_s
      json.field "chapters" do
        json.array do
          @chapters.each do |chapter|
            json.object do
              json.field "title", chapter.title
              json.field "startMs", chapter.start_ms.total_milliseconds
              json.field "endMs", chapter.end_ms.total_milliseconds

              json.field "thumbnails" do
                json.array do
                  chapter.thumbnails.each do |thumbnail|
                    json.object do
                      json.field "url", URI.parse(thumbnail["url"].as(String)).request_target
                      json.field "width", thumbnail["width"]
                      json.field "height", thumbnail["height"]
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    # Create a JSON representation of the sequence of chapters
    def to_json
      JSON.build do |json|
        json.object do
          json.field "chapters" do
            json.object do
              to_json(json)
            end
          end
        end
      end
    end
  end
end
