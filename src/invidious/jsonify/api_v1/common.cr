require "json"

module Invidious::JSONify::APIv1
  extend self

  def thumbnails(json : JSON::Builder, id : String)
    json.array do
      build_thumbnails(id).each do |thumbnail|
        json.object do
          json.field "quality", thumbnail[:name]
          json.field "url", "#{thumbnail[:host]}/vi/#{id}/#{thumbnail["url"]}.jpg"
          json.field "width", thumbnail[:width]
          json.field "height", thumbnail[:height]
        end
      end
    end
  end
end
