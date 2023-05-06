module Invidious::Frontend::Comments
  extend self

  def template_youtube(comments, locale, thin_mode, is_replies = false)
    String.build do |html|
      root = comments["comments"].as_a
      root.each do |child|
        if child["replies"]?
          replies_count_text = translate_count(locale,
            "comments_view_x_replies",
            child["replies"]["replyCount"].as_i64 || 0,
            NumberFormatting::Separator
          )

          replies_html = <<-END_HTML
          <div id="replies" class="pure-g">
            <div class="pure-u-1-24"></div>
            <div class="pure-u-23-24">
              <p>
                <a href="javascript:void(0)" data-continuation="#{child["replies"]["continuation"]}"
                  data-onclick="get_youtube_replies" data-load-replies>#{replies_count_text}</a>
              </p>
            </div>
          </div>
          END_HTML
        end

        if !thin_mode
          author_thumbnail = "/ggpht#{URI.parse(child["authorThumbnails"][-1]["url"].as_s).request_target}"
        else
          author_thumbnail = ""
        end

        author_name = HTML.escape(child["author"].as_s)
        sponsor_icon = ""
        if child["verified"]?.try &.as_bool && child["authorIsChannelOwner"]?.try &.as_bool
          author_name += "&nbsp;<i class=\"icon ion ion-md-checkmark-circle\"></i>"
        elsif child["verified"]?.try &.as_bool
          author_name += "&nbsp;<i class=\"icon ion ion-md-checkmark\"></i>"
        end

        if child["isSponsor"]?.try &.as_bool
          sponsor_icon = String.build do |str|
            str << %(<img alt="" )
            str << %(src="/ggpht) << URI.parse(child["sponsorIconUrl"].as_s).request_target << "\" "
            str << %(title=") << translate(locale, "Channel Sponsor") << "\" "
            str << %(width="16" height="16" />)
          end
        end
        html << <<-END_HTML
        <div class="pure-g" style="width:100%">
          <div class="channel-profile pure-u-4-24 pure-u-md-2-24">
            <img loading="lazy" style="margin-right:1em;margin-top:1em;width:90%" src="#{author_thumbnail}" alt="" />
          </div>
          <div class="pure-u-20-24 pure-u-md-22-24">
            <p>
              <b>
                <a class="#{child["authorIsChannelOwner"] == true ? "channel-owner" : ""}" href="#{child["authorUrl"]}">#{author_name}</a>
              </b>
              #{sponsor_icon}
              <p style="white-space:pre-wrap">#{child["contentHtml"]}</p>
        END_HTML

        if child["attachment"]?
          attachment = child["attachment"]

          case attachment["type"]
          when "image"
            attachment = attachment["imageThumbnails"][1]

            html << <<-END_HTML
            <div class="pure-g">
              <div class="pure-u-1 pure-u-md-1-2">
                <img loading="lazy" style="width:100%" src="/ggpht#{URI.parse(attachment["url"].as_s).request_target}" alt="" />
              </div>
            </div>
            END_HTML
          when "video"
            if attachment["error"]?
              html << <<-END_HTML
              <div class="pure-g video-iframe-wrapper">
                <p>#{attachment["error"]}</p>
              </div>
              END_HTML
            else
              html << <<-END_HTML
              <div class="pure-g video-iframe-wrapper">
                <iframe class="video-iframe" src='/embed/#{attachment["videoId"]?}?autoplay=0'></iframe>
              </div>
              END_HTML
            end
          else nil # Ignore
          end
        end

        html << <<-END_HTML
        <p>
          <span title="#{Time.unix(child["published"].as_i64).to_s(translate(locale, "%A %B %-d, %Y"))}">#{translate(locale, "`x` ago", recode_date(Time.unix(child["published"].as_i64), locale))} #{child["isEdited"] == true ? translate(locale, "(edited)") : ""}</span>
          |
        END_HTML

        if comments["videoId"]?
          html << <<-END_HTML
            <a href="https://www.youtube.com/watch?v=#{comments["videoId"]}&lc=#{child["commentId"]}" title="#{translate(locale, "YouTube comment permalink")}">[YT]</a>
            |
          END_HTML
        elsif comments["authorId"]?
          html << <<-END_HTML
            <a href="https://www.youtube.com/channel/#{comments["authorId"]}/community?lb=#{child["commentId"]}" title="#{translate(locale, "YouTube comment permalink")}">[YT]</a>
            |
          END_HTML
        end

        html << <<-END_HTML
          <i class="icon ion-ios-thumbs-up"></i> #{number_with_separator(child["likeCount"])}
        END_HTML

        if child["creatorHeart"]?
          if !thin_mode
            creator_thumbnail = "/ggpht#{URI.parse(child["creatorHeart"]["creatorThumbnail"].as_s).request_target}"
          else
            creator_thumbnail = ""
          end

          html << <<-END_HTML
            &nbsp;
            <span class="creator-heart-container" title="#{translate(locale, "`x` marked it with a ❤", child["creatorHeart"]["creatorName"].as_s)}">
                <span class="creator-heart">
                    <img loading="lazy" class="creator-heart-background-hearted" src="#{creator_thumbnail}" alt="" />
                    <span class="creator-heart-small-hearted">
                        <span class="icon ion-ios-heart creator-heart-small-container"></span>
                    </span>
                </span>
            </span>
          END_HTML
        end

        html << <<-END_HTML
            </p>
            #{replies_html}
          </div>
        </div>
        END_HTML
      end

      if comments["continuation"]?
        html << <<-END_HTML
        <div class="pure-g">
          <div class="pure-u-1">
            <p>
              <a href="javascript:void(0)" data-continuation="#{comments["continuation"]}"
                data-onclick="get_youtube_replies" data-load-more #{"data-load-replies" if is_replies}>#{translate(locale, "Load more")}</a>
            </p>
          </div>
        </div>
        END_HTML
      end
    end
  end
end
