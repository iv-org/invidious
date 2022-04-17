require "xml"
require "http/server"

module Invidious::RssAtom
  extend self

  # TODO: Merge all of those in a single type
  alias AnyVideo = SearchVideo | ChannelVideo | PlaylistVideo

  #
  # Feed properties structure
  #

  alias AltLink = NamedTuple(type: String, url: String)

  struct AtomProperties
    getter title : String
    getter icon_url : String
    getter author : String
    getter author_url : String

    getter date_published : String
    getter date_updated : String

    getter alt_links : Array(AltLink)

    def initialize(
      *, # All parameters must be named
      @title = "", @icon_url = "",
      @author = "", @author_url = "",
      date_updated : Time | String = Time.utc,
      date_published : Time | String = "",
      @alt_links = [] of AltLink
    )
      # Convert publication date if needed
      if date_published.is_a?(Time)
        @date_published = date_published.to_rfc3339
      else
        @date_published = date_published
      end

      # Convert update date if needed
      if date_updated.is_a?(Time)
        @date_updated = date_updated.to_rfc3339
      else
        @date_updated = date_updated
      end
    end
  end

  #
  # Atom Feed builder
  #

  def atom_feed_builder(
    # Mandatory parameters
    env : HTTP::Server::Context,
    videos : Array(AnyVideo),
    id : String,
    properties : AtomProperties
  )
    locale = env.get("preferences").as(Preferences).locale
    params = HTTP::Params.parse(env.params.query["params"]? || "")

    return XML.build(indent: "  ", encoding: "UTF-8") do |xml|
      xml.element("feed",
        xmlns: "http://www.w3.org/2005/Atom",
        "xmlns:media": "http://search.yahoo.com/mrss/",
        "xml:lang": "en-US"
      ) do
        # The id must be unique, and an IANA-approved IRI, so use "ni://"
        # Relevant RFC documents:
        #  - https://datatracker.ietf.org/doc/html/rfc4287#section-4.2.6
        #  - https://datatracker.ietf.org/doc/html/rfc6920
        #
        xml.element("id") { xml.text "ni://invidious/sha-256;" + sha256(id) }

        # Feed title. Use author name if no title was provided
        xml.element("title") do
          xml.text(properties.title.empty? ? properties.author : properties.title)
        end

        if !properties.icon_url.empty?
          icon_url = "#{HOST_URL}/gghpt/#{URI.parse(properties.icon_url).request_target}"
          xml.element("icon") { xml.text icon_url }
          xml.element("logo") { xml.text icon_url }
        end

        # Feed creation (if available) and update (mandatory) dates
        if !properties.date_published.empty?
          xml.element("published") { xml.text properties.date_published }
        end

        xml.element("updated") { xml.text properties.date_updated }

        # Links
        xml.element("link", rel: "self",
          type: "application/atom+xml",
          href: "#{HOST_URL}#{env.request.resource}"
        )

        properties.alt_links.each do |link|
          xml.element("link", rel: "alternate", type: link[:type], href: link[:url])
        end

        # Author infos
        xml.element("author") do
          xml.element("name") { xml.text properties.author }
          xml.element("uri") { xml.text properties.author_url } if !properties.author_url.empty?
        end

        # Video entries
        videos.each do |video|
          xml.element("entry") { atom_video(xml, video, params) }
        end
      end
    end
  end

  def atom_video(xml : XML::Builder, video : AnyVideo, query_params : HTTP::Params)
    # URLs that are reused below
    video_url = "#{HOST_URL}/watch?v=#{video.id}&#{query_params}"
    video_thumb = "#{HOST_URL}/vi/#{video.id}/mqdefault.jpg"

    description = video.is_a?(SearchVideo) ? video.description_html : ""

    xml.element("id") { xml.text "ni://invidious/sha-256;" + sha256("video/#{video.id}") }
    xml.element("title") { xml.text video.title }
    xml.element("link", rel: "alternate", href: video_url)

    xml.element("author") do
      xml.element("name") { xml.text video.author }
      xml.element("uri") { xml.text "#{HOST_URL}/channel/#{video.ucid}" }
    end

    xml.element("content", type: "xhtml") do
      xml.element("div", xmlns: "http://www.w3.org/1999/xhtml") do
        # Link to video
        xml.element("a", href: video_url) do
          xml.element("img", src: video_thumb)
        end

        # Video sescription (SearchVideo only)
        if video.is_a?(SearchVideo)
          xml.element("p", style: "white-space:pre-wrap") { xml.text description }
        end
      end
    end

    # Feed creation (if available) and update (ChannelVideo only) dates
    xml.element("published") { xml.text video.published.to_rfc3339 }
    xml.element("updated") { xml.text video.updated.to_rfc3339 } if video.is_a?(ChannelVideo)

    # Media properties
    xml.element("media:group") do
      xml.element("media:title") { xml.text video.title }
      xml.element("media:thumbnail", url: video_thumb, width: "320", height: "180")

      # Video sescription (SearchVideo only)
      if video.is_a?(SearchVideo)
        xml.element("media:description") { xml.text description }
      end
    end

    # Views count (all except PlaylistVideo)
    if !video.is_a?(PlaylistVideo)
      xml.element("media:community") do
        xml.element("media:statistics", views: video.views)
      end
    end
  end
end
