module Invidious::Frontend::WatchPage
  extend self

  # A handy structure to pass many elements at
  # once to the download widget function
  struct VideoAssets
    getter full_videos : Array(Hash(String, JSON::Any))
    getter video_streams : Array(Hash(String, JSON::Any))
    getter audio_streams : Array(Hash(String, JSON::Any))
    getter captions : Array(Invidious::Videos::Captions::Metadata)

    def initialize(
      @full_videos,
      @video_streams,
      @audio_streams,
      @captions,
    )
    end
  end

  def download_widget(locale : String, video : Video, video_assets : VideoAssets) : String
    if CONFIG.disabled?("downloads")
      return "<p id=\"download\">#{I18n.translate(locale, "Download is disabled")}</p>"
    end

    if CONFIG.dmca_content.includes?(video.id)
      return "<p id=\"download\">#{I18n.translate(locale, "dmca_content")}</p>"
    end

    url = "/download"
    if (CONFIG.invidious_companion.present?)
      invidious_companion = CONFIG.invidious_companion.sample
      url = "#{invidious_companion.public_url}/download?check=#{invidious_companion_encrypt(video.id)}"
    end

    return String.build(4000) do |str|
      str << "<form"
      str << " class=\"pure-form pure-form-stacked\""
      str << " action='" << HTML.escape(url) << "'"
      str << " method='post'"
      str << " rel='noopener noreferrer'"
      str << " target='_blank'>"
      str << '\n'

      # Hidden inputs for video id and title
      str << "<input type='hidden' name='id' value='" << video.id << "'/>\n"
      str << "<input type='hidden' name='title' value='" << HTML.escape(video.title) << "'/>\n"

      str << "\t<div class=\"pure-control-group\">\n"

      str << "\t\t<label for='download_widget'>"
      str << I18n.translate(locale, "Download as: ")
      str << "</label>\n"

      str << "\t\t<select name='download_widget' id='download_widget'>\n"

      # Non-DASH videos (audio+video)

      video_assets.full_videos.each do |option|
        mimetype = option["mimeType"].as_s.split(";")[0]

        height = Invidious::Videos::Formats.itag_to_metadata?(option["itag"]).try &.["height"]?

        value = {"itag": option["itag"], "ext": mimetype.split("/")[1]}.to_json

        str << "\t\t\t<option value='" << value << "'>"
        str << (height || "~240") << "p - " << mimetype
        str << "</option>\n"
      end

      # DASH video streams

      video_assets.video_streams.each do |option|
        mimetype = option["mimeType"].as_s.split(";")[0]

        value = {"itag": option["itag"], "ext": mimetype.split("/")[1]}.to_json

        str << "\t\t\t<option value='" << value << "'>"
        str << option["qualityLabel"] << " - " << mimetype << " @ " << option["fps"] << "fps - video only"
        str << "</option>\n"
      end

      # DASH audio streams

      video_assets.audio_streams.each do |option|
        mimetype = option["mimeType"].as_s.split(";")[0]

        value = {"itag": option["itag"], "ext": mimetype.split("/")[1]}.to_json

        str << "\t\t\t<option value='" << value << "'>"
        str << mimetype << " @ " << (option["bitrate"]?.try &.as_i./ 1000) << "k - audio only"
        str << "</option>\n"
      end

      # Subtitles (a.k.a "closed captions")

      video_assets.captions.each do |caption|
        value = {"label": caption.name, "ext": "#{caption.language_code}.vtt"}.to_json

        str << "\t\t\t<option value='" << value << "'>"
        str << I18n.translate(locale, "download_subtitles", I18n.translate(locale, caption.name))
        str << "</option>\n"
      end

      # End of form

      str << "\t\t</select>\n"
      str << "\t</div>\n"

      str << "\t<button type=\"submit\" class=\"pure-button pure-button-primary\">\n"
      str << "\t\t<b>" << I18n.translate(locale, "Download") << "</b>\n"
      str << "\t</button>\n"

      str << "</form>\n"
    end
  end

  def template_related_videos(related, locale, thin_mode, listen)
    String.build do |html|
      related.each do |rv|
        id = rv["id"]? || rv[:id]?
        next if !id

        author = rv["author"]? || rv[:author]? || ""
        ucid = rv["ucid"]? || rv[:ucid]? || ""
        author_verified = (rv["author_verified"]? || rv[:author_verified]?).to_s == "true"
        title = rv["title"]? || rv[:title]? || ""
        length_seconds = (rv["length_seconds"]? || rv[:length_seconds]?).try &.to_s.to_i?
        short_view_count = (rv["short_view_count"]? || rv[:short_view_count]?).try &.to_s || "0"

        html << %(<div class="pure-u-1">)
        html << %(<div class="thumbnail">)
        if !thin_mode
          html << %(<a tabindex="-1" href="/watch?v=) << id << %(&listen=) << (listen ? "true" : "false") << %(">)
          html << %(<img loading="lazy" class="thumbnail" src="/vi/) << id << %(/mqdefault.jpg" alt="" />)
          html << %(</a>)
        else
          html << %(<div class="thumbnail-placeholder"></div>)
        end
        if length_seconds && length_seconds != 0
          html << %(<div class="bottom-right-overlay"><p class="length">) << recode_length_seconds(length_seconds) << %(</p></div>)
        end
        html << %(</div>)

        html << %(<div class="video-card-row"><a href="/watch?v=) << id << %(&listen=) << (listen ? "true" : "false") << %("><p dir="auto">) << HTML.escape(title.to_s) << %(</p></a></div>)

        html << %(<h5 class="pure-g">)
        html << %(<div class="pure-u-14-24">)
        if !ucid.to_s.empty?
          html << %(<b style="width:100%"><a href="/channel/) << ucid << %(">) << HTML.escape(author.to_s)
          if author_verified
            html << %(&nbsp;<i class="icon ion ion-md-checkmark-circle"></i>)
          end
          html << %(</a></b>)
        else
          html << %(<b style="width:100%">) << HTML.escape(author.to_s)
          if author_verified
            html << %(&nbsp;<i class="icon ion ion-md-checkmark-circle"></i>)
          end
          html << %(</b>)
        end
        html << %(</div>)
        html << %(<div class="pure-u-10-24" style="text-align:right">)
        views = short_text_to_number(short_view_count)
        html << %(<b class="width:100%">) << I18n.translate_count(locale, "generic_views_count", views, I18n::NumberFormatting::Short) << %(</b>)
        html << %(</div>)
        html << %(</h5>)
        html << %(</div>)
      end
    end
  end
end
