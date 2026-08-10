# frozen_string_literal: true

require "json"

module Pickpoint
  class RoutingService
    def initialize(transport)
      @t = transport
    end

    def route(body)
      post("/v2/route", body)
    end

    def optimized(body)
      post("/v2/route/optimized", body)
    end

    def matrix(body)
      post("/v2/route/matrix", body)
    end

    def locate(body)
      post("/v2/route/locate", body)
    end

    def elevation(body)
      post("/v2/route/elevation", body)
    end

    private

    def post(path, body)
      raw = @t.do(Transport::RequestOpts.new(method: "POST", path: path, body: body))
      return nil if raw.nil? || raw.empty?

      JSON.parse(raw)
    end
  end
end
