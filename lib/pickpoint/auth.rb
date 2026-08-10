# frozen_string_literal: true

require "json"
require "monitor"

module Pickpoint
  module Auth
    module_function

    def resolve(cfg, base_url, http)
      n = 0
      n += 1 if present?(cfg.api_key)
      n += 1 if cfg.client_auth
      n += 1 if present?(cfg.access_token)
      if n > 1
        raise InvalidConfigError, "provide only one of: api_key | client_auth | access_token"
      end
      if n.zero?
        raise InvalidConfigError, "auth required: api_key, client_auth, or access_token"
      end

      if present?(cfg.api_key)
        return State.new(api_key: cfg.api_key)
      end
      if cfg.client_auth
        return State.new(session: ClientAuthSession.new(cfg.client_auth, base_url, http))
      end

      State.new(session: StaticSession.new(cfg.access_token))
    end

    def present?(s)
      !s.nil? && !s.to_s.empty?
    end

    class State
      def initialize(api_key: nil, session: nil)
        @api_key = api_key
        @session = session
      end

      def bearer?
        !@session.nil?
      end

      def apply!(headers)
        headers["Accept"] = "application/json"
        if @api_key
          headers["x-api-key"] = @api_key
          return
        end
        headers["Authorization"] = "Bearer #{@session.token}"
      end

      def refresh_after_unauthorized
        return false if @session.nil?

        @session.refresh_after_unauthorized
      end
    end

    class StaticSession
      def initialize(access_token)
        @token = access_token
      end

      def token
        @token
      end

      def refresh_after_unauthorized
        false
      end
    end

    class ClientAuthSession
      def initialize(initial, base_url, http)
        if blank?(initial.access_token) || blank?(initial.refresh_token) || initial.expires_at.to_i.zero?
          raise InvalidConfigError,
                "client_auth requires access_token, refresh_token, and expires_at (unix ms)"
        end
        @mutex = Monitor.new
        @cond = @mutex.new_cond
        @access = initial.access_token
        @refresh = initial.refresh_token
        @expires_at = initial.expires_at.to_i
        @issued_at = Time.now
        @base_url = base_url
        @http = http
        @refreshing = false
        @waiters = 0
        @last_refresh_error = nil
      end

      def token
        refresh if needs_proactive_refresh?
        @mutex.synchronize { @access }
      end

      def refresh_after_unauthorized
        refresh
        true
      rescue StandardError
        false
      end

      def refresh
        wait = false
        refresh_tok = nil

        @mutex.synchronize do
          if @refreshing
            @waiters += 1
            wait = true
          else
            @refreshing = true
            @last_refresh_error = nil
            refresh_tok = @refresh
          end
        end

        if wait
          @mutex.synchronize do
            @cond.wait_while { @refreshing }
            err = @last_refresh_error
            @waiters -= 1
            raise err if err
          end
          return
        end

        err = nil
        begin
          do_refresh(refresh_tok)
        rescue StandardError => e
          err = e
        end

        @mutex.synchronize do
          @last_refresh_error = err
          @refreshing = false
          @cond.broadcast
        end

        raise err if err
      end

      private

      def blank?(s)
        s.nil? || s.to_s.empty?
      end

      def needs_proactive_refresh?
        now_ms = (Time.now.to_f * 1000).to_i
        issued_ms = (@issued_at.to_f * 1000).to_i
        ttl_ms = @expires_at - issued_ms
        if ttl_ms <= 0
          return now_ms >= (@expires_at - 30_000)
        end

        refresh_after_s = (ttl_ms * CLIENT_AUTH_REFRESH_AT) / 1000.0
        (Time.now - @issued_at) >= refresh_after_s
      end

      def do_refresh(refresh_tok)
        status, raw =
          begin
            @http.request(
              "POST",
              "#{@base_url}/v2/client-tokens/refresh",
              headers: {
                "Accept" => "application/json",
                "Content-Type" => "application/json"
              },
              body: JSON.generate({ "refreshToken" => refresh_tok })
            )
          rescue StandardError => e
            raise APIError.new(code: "REFRESH_FAILED", message: "client token refresh network error: #{e}")
          end

        unless status >= 200 && status < 300
          raise APIError.new(
            status: status,
            code: "REFRESH_FAILED",
            message: "client token refresh failed (#{status})",
            body: raw
          )
        end

        begin
          pair = JSON.parse(raw)
        rescue JSON::ParserError => e
          raise APIError.new(code: "INVALID_TOKEN", message: "refresh returned invalid JSON: #{e}", body: raw)
        end

        access = pair["accessToken"].to_s
        refresh = pair["refreshToken"].to_s
        expires = pair["expiresAt"].to_i
        if access.empty? || refresh.empty? || expires.zero?
          raise APIError.new(code: "INVALID_TOKEN", message: "refresh returned invalid clientAuth pair", body: raw)
        end

        @mutex.synchronize do
          @access = access
          @refresh = refresh
          @expires_at = expires
          @issued_at = Time.now
        end
      end
    end
  end
end
