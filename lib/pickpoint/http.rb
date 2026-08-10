# frozen_string_literal: true

require "net/http"
require "uri"

module Pickpoint
  # Thin Net::HTTP wrapper. Optional +adapter+ responds to
  # +call(method, url, headers, body) -> [status, body_string]+.
  class Http
    def initialize(timeout:, adapter: nil)
      @timeout = timeout
      @adapter = adapter
    end

    def request(method, url, headers: {}, body: nil)
      return @adapter.call(method, url, headers, body) if @adapter

      uri = URI(url)
      req = build_request(method, uri, body)
      headers.each { |k, v| req[k] = v }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @timeout
      http.read_timeout = @timeout
      res = http.request(req)
      [res.code.to_i, res.body.to_s]
    end

    private

    def build_request(method, uri, body)
      m = method.to_s.upcase
      klass =
        case m
        when "GET" then Net::HTTP::Get
        when "POST" then Net::HTTP::Post
        when "PATCH" then Net::HTTP::Patch
        when "PUT" then Net::HTTP::Put
        when "DELETE" then Net::HTTP::Delete
        else
          raise InvalidConfigError, "unsupported HTTP method: #{m}"
        end

      req = klass.new(uri.request_uri)
      unless body.nil?
        req["Content-Type"] = "application/json"
        req.body = body
      end
      req
    end
  end
end
