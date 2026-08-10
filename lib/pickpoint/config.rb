# frozen_string_literal: true

module Pickpoint
  DEFAULT_BASE_URL = "https://api.pickpoint.io"
  DEFAULT_MAX_RETRIES = 3
  DEFAULT_RETRY_BASE = 1.0 # seconds
  MIN_RETRY_BASE = 0.2
  DEFAULT_TIMEOUT = 30.0
  MAX_CONCURRENCY = 20
  DEFAULT_CONCURRENCY = 20
  CLIENT_AUTH_REFRESH_AT = 0.5

  # Pair from POST /v2/client-tokens. +expires_at+ is unix epoch milliseconds.
  ClientAuth = Struct.new(:access_token, :refresh_token, :expires_at, keyword_init: true)

  # Public-api client config. Provide exactly one of +api_key+ / +client_auth+ / +access_token+.
  class Config
    attr_accessor :api_key, :client_auth, :access_token, :base_url,
                  :max_retries, :retry_base, :timeout, :concurrency, :http_adapter

    def initialize(
      api_key: nil,
      client_auth: nil,
      access_token: nil,
      base_url: nil,
      max_retries: nil,
      retry_base: nil,
      timeout: nil,
      concurrency: nil,
      http_adapter: nil
    )
      @api_key = api_key
      @client_auth = client_auth
      @access_token = access_token
      @base_url = base_url
      @max_retries = max_retries
      @retry_base = retry_base
      @timeout = timeout
      @concurrency = concurrency
      # Optional callable: call(method, url, headers, body) -> [status, body]
      @http_adapter = http_adapter
    end
  end
end
