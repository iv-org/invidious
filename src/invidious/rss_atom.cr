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
        # TODO: Unify `.to_xml` methods
        videos.each do |video|
          case video
          when .is_a?(PlaylistVideo) then video.to_xml(xml)
          when .is_a?(ChannelVideo)  then video.to_xml(locale, params, xml)
          when .is_a?(SearchVideo)   then video.to_xml(false, params, xml)
          end
        end
      end
    end
  end
end
