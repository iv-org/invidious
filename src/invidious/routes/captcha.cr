module Invidious::Routes::Captcha
  def self.get(env)
    headers = HTTP::Headers{":authority" => "accounts.google.com"}
    response = YT_POOL.client &.get(env.request.resource, headers)
    env.response.headers["Content-Type"] = response.headers["Content-Type"]
    response.body
  end
end
