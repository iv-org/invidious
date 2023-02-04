module Invidious::Frontend::WatchPage
  extend self

  # A handy structure to pass many elements at
  # once to the download widget function
  struct VideoAssets
    getter full_videos : Array(Videos::ProgressiveHttpStream)
    getter video_streams : Array(Videos::AdaptativeVideoStream)
    getter audio_streams : Array(Videos::AdaptativeAudioStream)
    getter captions : Array(Invidious::Videos::Captions::Metadata)

    def initialize(
      @full_videos,
      @video_streams,
      @audio_streams,
      @captions
    )
    end
  end

  def download_widget(locale : String, video : Video, video_assets : VideoAssets) : String
    if CONFIG.disabled?("downloads")
      return "<p id=\"download\">#{translate(locale, "Download is disabled")}</p>"
    end

    return String.build(4000) do |str|
      str << "<form"
      str << " class=\"pure-form pure-form-stacked\""
      str << " action='/download'"
      str << " method='post'"
      str << " rel='noopener'"
      str << " target='_blank'>"
      str << '\n'

      # Hidden inputs for video id and title
      str << "<input type='hidden' name='id' value='" << video.id << "'/>\n"
      str << "<input type='hidden' name='title' value='" << HTML.escape(video.title) << "'/>\n"

      str << "\t<div class=\"pure-control-group\">\n"

      str << "\t\t<label for='download_widget'>"
      str << translate(locale, "Download as: ")
      str << "</label>\n"

      str << "\t\t<select name='download_widget' id='download_widget'>\n"

      # Non-DASH videos (audio+video)

      video_assets.full_videos.each do |option|
        height = Invidious::Videos::Formats.itag_to_metadata?(option.itag).try &.["height"]?

        value = {"itag": option.itag, "ext": option.mime_type.split("/")[1]}.to_json

        str << "\t\t\t<option value='" << value << "'>"
        str << (height || option.video_height) << "p - " << option.mime_type
        str << "</option>\n"
      end

      # DASH video streams

      video_assets.video_streams.each do |option|
        value = {"itag": option.itag, "ext": option.mime_type.split("/")[1]}.to_json

        str << "\t\t\t<option value='" << value << "'>"
        str << option.label << " - " << option.mime_type
        str << " @ " << option.video_fps << "fps - video only"
        str << "</option>\n"
      end

      # DASH audio streams

      video_assets.audio_streams.each do |option|
        value = {"itag": option.itag, "ext": option.mime_type.split("/")[1]}.to_json

        str << "\t\t\t<option value='" << value << "'>"
        str << option.mime_type << " @ " << (option.bitrate // 1000) << "kbps - audio only"
        str << "</option>\n"
      end

      # Subtitles (a.k.a "closed captions")

      video_assets.captions.each do |caption|
        value = {"label": caption.name, "ext": "#{caption.language_code}.vtt"}.to_json

        str << "\t\t\t<option value='" << value << "'>"
        str << translate(locale, "download_subtitles", translate(locale, caption.name))
        str << "</option>\n"
      end

      # End of form

      str << "\t\t</select>\n"
      str << "\t</div>\n"

      str << "\t<button type=\"submit\" class=\"pure-button pure-button-primary\">\n"
      str << "\t\t<b>" << translate(locale, "Download") << "</b>\n"
      str << "\t</button>\n"

      str << "</form>\n"
    end
  end
end
