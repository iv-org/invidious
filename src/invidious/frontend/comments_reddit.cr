module Invidious::Frontend::Comments
  extend self

  def template_reddit(root, locale)
    String.build do |html|
      root.each do |child|
        if child.data.is_a?(RedditComment)
          child = child.data.as(RedditComment)
          body_html = HTML.unescape(child.body_html)

          replies_html = ""
          if child.replies.is_a?(RedditThing)
            replies = child.replies.as(RedditThing)
            replies_html = self.template_reddit(replies.data.as(RedditListing).children, locale)
          end

          if child.depth > 0
            html << <<-END_HTML
            <div class="pure-g">
            <div class="pure-u-1-24">
            </div>
            <div class="pure-u-23-24">
            END_HTML
          else
            html << <<-END_HTML
            <div class="pure-g">
            <div class="pure-u-1">
            END_HTML
          end

          html << <<-END_HTML
          <p>
            <a href="javascript:void(0)" data-onclick="toggle_parent">[ − ]</a>
            <b><a href="https://www.reddit.com/user/#{child.author}">#{child.author}</a></b>
            #{translate_count(locale, "comments_points_count", child.score, NumberFormatting::Separator)}
            <span title="#{child.created_utc.to_s(translate(locale, "%a %B %-d %T %Y UTC"))}">#{translate(locale, "`x` ago", recode_date(child.created_utc, locale))}</span>
            <a href="https://www.reddit.com#{child.permalink}" title="#{translate(locale, "permalink")}">#{translate(locale, "permalink")}</a>
            </p>
            <div>
            #{body_html}
            #{replies_html}
          </div>
          </div>
          </div>
          END_HTML
        end
      end
    end
  end
end
