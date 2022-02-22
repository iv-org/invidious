module Invidious::Frontend::WatchPage
  extend self

  # A handy structure to pass many elements at
  # once to the download widget function
  struct VideoAssets
    getter full_videos : Array(Hash(String, JSON::Any))
    getter video_streams : Array(Hash(String, JSON::Any))
    getter audio_streams : Array(Hash(String, JSON::Any))
    getter captions : Array(Caption)

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
      return "<p id=\"download\">#{translate(locale, "Download is disabled.")}</p>"
    end

    return String.build(4000) do |str|
      str << "<form"
      str << " class=\"pure-form pure-form-stacked\""
      str << " action='/latest_version'"
      str << " method='get'"
      str << " rel='noopener'"
      str << " target='_blank'>"
      str << '\n'

      str << "\t<div class=\"pure-control-group\">\n"

      str << "\t\t<label for='download_widget'>"
      str << translate(locale, "Download as: ")
      str << "</label>\n"

      # TODO: remove inline style
      str << "\t\t<select style=\"width:100%\" name='download_widget' id='download_widget'>\n"

      # Non-DASH videos (audio+video)

      video_assets.full_videos.each do |option|
        mimetype = option["mimeType"].as_s.split(";")[0]

        height = itag_to_metadata?(option["itag"]).try &.["height"]?

        title = URI.encode_www_form("#{video.title}-#{video.id}.#{mimetype.split("/")[1]}")
        value = {"id": video.id, "itag": option["itag"], "title": title}.to_json

        str << "\t\t\t<option value='" << value << "'>"
        str << (height || "~240") << "p - " << mimetype
        str << "</option>\n"
      end

      # DASH video streams

      video_assets.video_streams.each do |option|
        mimetype = option["mimeType"].as_s.split(";")[0]

        title = URI.encode_www_form("#{video.title}-#{video.id}.#{mimetype.split("/")[1]}")
        value = {"id": video.id, "itag": option["itag"], "title": title}.to_json

        str << "\t\t\t<option value='" << value << "'>"
        str << option["qualityLabel"] << " - " << mimetype << " @ " << option["fps"] << "fps - video only"
        str << "</option>\n"
      end

      # DASH audio streams

      video_assets.audio_streams.each do |option|
        mimetype = option["mimeType"].as_s.split(";")[0]

        title = URI.encode_www_form("#{video.title}-#{video.id}.#{mimetype.split("/")[1]}")
        value = {"id": video.id, "itag": option["itag"], "title": title}.to_json

        str << "\t\t\t<option value='" << value << "'>"
        str << mimetype << " @ " << (option["bitrate"]?.try &.as_i./ 1000) << "k - audio only"
        str << "</option>\n"
      end

      # Subtitles (a.k.a "closed captions")

      video_assets.captions.each do |caption|
        title = URI.encode_www_form("#{video.title}-#{video.id}.#{caption.language_code}.vtt")
        value = {"id": video.id, "label": caption.name, "title": title}.to_json

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
