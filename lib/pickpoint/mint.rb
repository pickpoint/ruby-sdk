# frozen_string_literal: true

require "json"

module Pickpoint
  TokenPair = Struct.new(
    :access_token, :refresh_token, :expires_at, :expires_in, :scopes,
    keyword_init: true
  ) do
    def self.from_hash(d)
      d = d.transform_keys(&:to_s)
      new(
        access_token: (d["accessToken"] || "").to_s,
        refresh_token: (d["refreshToken"] || "").to_s,
        expires_at: (d["expiresAt"] || 0).to_i,
        expires_in: (d["expiresIn"] || 0).to_i,
        scopes: Array(d["scopes"])
      )
    end
  end

  module_function

  # Mint a client-token pair with a secret API key (server-side).
  def mint_client_tokens(cfg, scopes: nil, ttl_sec: nil)
    raise InvalidConfigError, "mint_client_tokens requires api_key" if cfg.api_key.nil? || cfg.api_key.empty?

    base = Transport.trim_slash(cfg.base_url || DEFAULT_BASE_URL)
    timeout = cfg.timeout && cfg.timeout.positive? ? cfg.timeout : DEFAULT_TIMEOUT
    http = Http.new(timeout: timeout, adapter: cfg.http_adapter)

    payload = { "scopes" => scopes || [] }
    payload["ttlSec"] = ttl_sec if ttl_sec && ttl_sec.positive?

    begin
      status, raw = http.request(
        "POST",
        "#{base}/v2/client-tokens",
        headers: {
          "Accept" => "application/json",
          "Content-Type" => "application/json",
          "x-api-key" => cfg.api_key
        },
        body: JSON.generate(payload)
      )
    rescue StandardError => e
      raise APIError.new(code: "NETWORK", message: "mint client tokens network error: #{e}")
    end

    unless status >= 200 && status < 300
      raise APIError.new(
        status: status,
        code: "CLIENT_ERROR",
        message: "mint client tokens failed (#{status})",
        body: raw
      )
    end

    TokenPair.from_hash(JSON.parse(raw))
  end
end
