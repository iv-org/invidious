require "oauth2"

module Invidious::OAuthHelper
  extend self

  def get_provider(key)
    if provider = CONFIG.oauth[key]?
      provider
    else
      raise Exception.new("Invalid OAuth Endpoint: " + key)
    end
  end

  def make_client(key)
    if HOST_URL == ""
      raise Exception.new("Missing domain and port configuration")
    end
    provider = get_provider(key)
    redirect_uri = "#{HOST_URL}/login/oauth/#{key}"
    OAuth2::Client.new(
      provider.host,
      provider.client_id,
      provider.client_secret,
      authorize_uri: provider.auth_uri,
      token_uri: provider.token_uri,
      redirect_uri: redirect_uri
    )
  end

  def get_uri_host_pair(host, url)
    if (url.starts_with?(/https*\:\/\//))
      uri = URI.parse url
      [uri.host || host, uri.path || "/"]
    else
      [host, url]
    end
  end

  def get_info(key, token)
    provider = self.get_provider(key)
    uri_host_pair = self.get_uri_host_pair(provider.host, provider.info_uri)
    client = HTTP::Client.new(uri_host_pair[0], tls: true)
    token.authenticate(client)
    response = client.get uri_host_pair[1]
    client.close
    response.body
  end

  def info_field(key, token)
    info = JSON.parse(self.get_info(key, token))
    info[self.get_provider(key).field].as_s?
  end
end
