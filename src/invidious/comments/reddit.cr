module Invidious::Comments
  extend self

  def fetch_reddit(id, sort_by = "confidence")
    client = make_client(REDDIT_URL)
    headers = HTTP::Headers{"User-Agent" => "web:invidious:v#{CURRENT_VERSION} (by github.com/iv-org/invidious)"}

    # TODO: Use something like #479 for a static list of instances to use here
    query = URI::Params.encode({q: "(url:3D#{id} OR url:#{id}) AND (site:invidio.us OR site:youtube.com OR site:youtu.be)"})
    search_results = client.get("/search.json?#{query}", headers)

    if search_results.status_code == 200
      search_results = RedditThing.from_json(search_results.body)

      # For videos that have more than one thread, choose the one with the highest score
      threads = search_results.data.as(RedditListing).children
      thread = threads.max_by?(&.data.as(RedditLink).score).try(&.data.as(RedditLink))
      result = thread.try do |t|
        body = client.get("/r/#{t.subreddit}/comments/#{t.id}.json?limit=100&sort=#{sort_by}", headers).body
        Array(RedditThing).from_json(body)
      end
      result ||= [] of RedditThing
    elsif search_results.status_code == 302
      # Previously, if there was only one result then the API would redirect to that result.
      # Now, it appears it will still return a listing so this section is likely unnecessary.

      result = client.get(search_results.headers["Location"], headers).body
      result = Array(RedditThing).from_json(result)

      thread = result[0].data.as(RedditListing).children[0].data.as(RedditLink)
    else
      raise NotFoundException.new("Comments not found.")
    end

    client.close

    comments = result[1]?.try(&.data.as(RedditListing).children)
    comments ||= [] of RedditThing
    return comments, thread
  end
end
