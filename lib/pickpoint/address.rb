# frozen_string_literal: true

require "json"

module Pickpoint
  class AddressService
    def initialize(transport)
      @t = transport
    end

    def search(query)
      q = (query || {}).transform_keys(&:to_s).transform_values(&:to_s)
      raw = @t.do(Transport::RequestOpts.new(method: "GET", path: "/v2/address/search", query: q))
      JSON.parse(raw)
    end
  end
end
