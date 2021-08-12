module Invidious::Routes::APIv1
  def self.channel_search(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    env.response.content_type = "application/json"

    ucid = env.params.url["ucid"]

    query = env.params.query["q"]?
    query ||= ""

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    count, search_results = channel_search(query, page, ucid)
    JSON.build do |json|
      json.array do
        search_results.each do |item|
          item.to_json(locale, json)
        end
      end
    end
  end
end
