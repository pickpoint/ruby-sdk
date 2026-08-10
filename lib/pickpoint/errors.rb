# frozen_string_literal: true

module Pickpoint
  class Error < StandardError; end

  class AuthError < Error; end
  class NotFoundError < Error; end
  class ConflictError < Error; end
  class InvalidConfigError < Error; end

  # Non-2xx public-api response (or transport failure after retries).
  class APIError < Error
    attr_reader :status, :code, :body

    def initialize(status: 0, code: "", message: "", body: "")
      @status = status
      @code = code.to_s
      @body = body.is_a?(String) ? body.b : body.to_s.b
      msg = message.empty? ? "request failed (status=#{status} code=#{code})" : message
      super("pickpoint: #{msg} (status=#{status} code=#{code})")
    end

    def auth?
      %w[API_AUTH REFRESH_FAILED].include?(code)
    end

    def not_found?
      code == "NOT_FOUND"
    end

    def conflict?
      code == "CONFLICT"
    end

    def invalid_config?
      code == "INVALID_CONFIG"
    end
  end
end
