require "crypto/subtle"

def generate_token(email, scopes, expire, key)
  session = "v1:#{Base64.urlsafe_encode(Random::Secure.random_bytes(32))}"
  Invidious::Database::SessionIDs.insert(session, email)

  token = {
    "session" => session,
    "scopes"  => scopes,
    "expire"  => expire,
  }

  if !expire
    token.delete("expire")
  end

  token["signature"] = sign_token(key, token)

  return token.to_json
end

def generate_response(session, scopes, key, expire = 6.hours, use_nonce = false)
  expire = Time.utc + expire

  token = {
    "session" => session,
    "expire"  => expire.to_unix,
    "scopes"  => scopes,
  }

  if use_nonce
    nonce = Random::Secure.hex(16)
    Invidious::Database::Nonces.insert(nonce, expire)
    token["nonce"] = nonce
  end

  token["signature"] = sign_token(key, token)

  return token.to_json
end

def sign_token(key, hash)
  string_to_sign = [] of String

  # TODO: figure out which "key" variable is used
  # Ameba reports a warning for "Lint/ShadowingOuterLocalVar" on this
  # variable, but it's preferable to not touch that (works fine atm).
  hash.each do |key, value|
    next if key == "signature"

    if value.is_a?(JSON::Any) && value.as_a?
      value = value.as_a.map(&.as_s)
    end

    case value
    when Array
      string_to_sign << "#{key}=#{value.sort.join(",")}"
    when Tuple
      string_to_sign << "#{key}=#{value.to_a.sort.join(",")}"
    else
      string_to_sign << "#{key}=#{value}"
    end
  end

  string_to_sign = string_to_sign.sort.join("\n")
  return Base64.urlsafe_encode(OpenSSL::HMAC.digest(:sha256, key, string_to_sign)).strip
end

def validate_request(token, session, request, key, locale = nil)
  case token
  when String
    token = JSON.parse(URI.decode_www_form(token)).as_h
  when JSON::Any
    token = token.as_h
  when Nil
    raise InfoException.new("Hidden field \"token\" is a required field")
  end

  expire = token["expire"]?.try &.as_i
  if expire.try &.< Time.utc.to_unix
    raise InfoException.new("Token is expired, please try again")
  end

  if token["session"] != session
    raise InfoException.new("Erroneous token")
  end

  scopes = token["scopes"].as_a.map(&.as_s)
  scope = "#{request.method}:#{request.path.lchop("/api/v1/auth/").lstrip("/")}"
  if !scopes_include_scope(scopes, scope)
    raise InfoException.new("Invalid scope")
  end

  if !Crypto::Subtle.constant_time_compare(token["signature"].to_s, sign_token(key, token))
    raise InfoException.new("Invalid signature")
  end

  if token["nonce"]? && (nonce = Invidious::Database::Nonces.select(token["nonce"].as_s))
    if nonce[1] > Time.utc
      Invidious::Database::Nonces.update_set_expired(nonce[0])
    else
      raise InfoException.new("Erroneous token")
    end
  end

  return {scopes, expire, token["signature"].as_s}
end

def scope_includes_scope(scope, subset)
  methods, endpoint = scope.split(":")
  methods = methods.split(";").map(&.upcase).reject(&.empty?).sort!
  endpoint = endpoint.downcase

  subset_methods, subset_endpoint = subset.split(":")
  subset_methods = subset_methods.split(";").map(&.upcase).sort!
  subset_endpoint = subset_endpoint.downcase

  if methods.empty?
    methods = %w(GET POST PUT HEAD DELETE PATCH OPTIONS)
  end

  if methods & subset_methods != subset_methods
    return false
  end

  if endpoint.ends_with?("*") && !subset_endpoint.starts_with? endpoint.rchop("*")
    return false
  end

  if !endpoint.ends_with?("*") && subset_endpoint != endpoint
    return false
  end

  return true
end

def scopes_include_scope(scopes, subset)
  scopes.each do |scope|
    if scope_includes_scope(scope, subset)
      return true
    end
  end

  return false
end
