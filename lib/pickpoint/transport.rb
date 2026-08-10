# frozen_string_literal: true

require "json"
require "uri"

module Pickpoint
  module Transport
    module_function

    def trim_slash(s)
      s.to_s.sub(%r{/+\z}, "")
    end

    ON_THROW = :throw
    ON_EMPTY = :empty

    RequestOpts = Struct.new(
      :method,
      :path,
      :query,
      :body,
      :on_client_error,
      :empty,
      keyword_init: true
    )

    class Client
      def initialize(base_url:, http:, auth:, max_retries:, retry_base:)
        @base_url = base_url
        @http = http
        @auth = auth
        @max_retries = max_retries
        @retry_base = retry_base
      end

      def do(opts)
        attempt = 0
        auth_retried = false

        loop do
          url = build_url(opts)
          headers = {}
          @auth.apply!(headers)
          body = opts.body.nil? ? nil : JSON.generate(opts.body)
          headers["Content-Type"] = "application/json" unless body.nil?

          begin
            status, raw = @http.request(opts.method || "GET", url, headers: headers, body: body)
          rescue StandardError => e
            raise APIError.new(code: "NETWORK", message: "network error: #{e}") if attempt >= @max_retries

            sleep_backoff(attempt)
            attempt += 1
            next
          end

          if status == 401
            if !auth_retried && @auth.bearer? && @auth.refresh_after_unauthorized
              auth_retried = true
              next
            end
            raise APIError.new(status: status, code: "API_AUTH", message: "auth failed (401)", body: raw)
          end

          if [402, 403].include?(status)
            raise APIError.new(status: status, code: "API_AUTH", message: "auth failed", body: raw)
          end

          return "" if status == 204

          if status == 409
            raise APIError.new(
              status: 409,
              code: "CONFLICT",
              message: message_from_body(raw, 409),
              body: raw
            )
          end

          if status == 400 || (status >= 404 && status < 500)
            return opts.empty || "" if opts.on_client_error == ON_EMPTY

            code = status == 404 ? "NOT_FOUND" : "CLIENT_ERROR"
            raise APIError.new(
              status: status,
              code: code,
              message: message_from_body(raw, status),
              body: raw
            )
          end

          if status >= 500
            if attempt >= @max_retries
              raise APIError.new(
                status: status,
                code: "SERVER_ERROR",
                message: "server error after retries",
                body: raw
              )
            end
            sleep_backoff(attempt)
            attempt += 1
            next
          end

          return raw if status >= 200 && status < 300

          return opts.empty || "" if status >= 400 && status < 500 && opts.on_client_error == ON_EMPTY

          raise APIError.new(
            status: status,
            code: "CLIENT_ERROR",
            message: message_from_body(raw, status),
            body: raw
          )
        end
      end

      private

      def build_url(opts)
        q = (opts.query || {}).reject { |_k, v| v.nil? || v.to_s.empty? }
        path = opts.path
        path = "#{path}?#{URI.encode_www_form(q)}" if q.any?
        "#{@base_url}#{path}"
      end

      def message_from_body(raw, status)
        begin
          m = JSON.parse(raw)
          if m.is_a?(Hash)
            return m["message"].to_s if m["message"]
            return m["error"].to_s if m["error"]
          end
        rescue JSON::ParserError
          # fall through
        end
        STATUS_TEXT.fetch(status, "unknown")
      end

      def sleep_backoff(attempt)
        base = @retry_base
        base = DEFAULT_RETRY_BASE if base <= 0
        base = [base, MIN_RETRY_BASE].max
        max_delay = base * (2**[attempt, 16].min)
        sleep(rand * max_delay)
      end
    end

    STATUS_TEXT = {
      400 => "Bad Request",
      401 => "Unauthorized",
      403 => "Forbidden",
      404 => "Not Found",
      409 => "Conflict",
      500 => "Internal Server Error",
      502 => "Bad Gateway",
      503 => "Service Unavailable"
    }.freeze
  end
end
