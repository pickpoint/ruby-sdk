# frozen_string_literal: true

require "json"
require "thread"

module Pickpoint
  class GeocodingService
    def initialize(transport, concurrency)
      @t = transport
      @concurrency = concurrency
    end

    def forward(query)
      raw = @t.do(
        Transport::RequestOpts.new(
          method: "GET",
          path: "/v2/geocode/forward",
          query: stringify_query(query),
          on_client_error: Transport::ON_EMPTY,
          empty: "[]"
        )
      )
      decode_json_array(raw)
    end

    def reverse(query)
      raw = @t.do(
        Transport::RequestOpts.new(
          method: "GET",
          path: "/v2/geocode/reverse",
          query: stringify_query(query),
          on_client_error: Transport::ON_EMPTY,
          empty: "null"
        )
      )
      return nil if raw.nil? || raw.empty? || raw == "null"

      JSON.parse(raw)
    end

    def lookup(query)
      raw = @t.do(
        Transport::RequestOpts.new(
          method: "GET",
          path: "/v2/address/lookup",
          query: stringify_query(query),
          on_client_error: Transport::ON_EMPTY,
          empty: "[]"
        )
      )
      decode_json_array(raw)
    end

    def forward_batch(queries)
      run_batch(queries) { |q| forward(q) }
    end

    def reverse_batch(queries)
      run_batch(queries) { |q| reverse(q) }
    end

    def lookup_batch(queries)
      run_batch(queries) { |q| lookup(q) }
    end

    private

    def stringify_query(query)
      (query || {}).transform_keys(&:to_s).transform_values(&:to_s)
    end

    def decode_json_array(raw)
      return [] if raw.nil? || raw.empty?

      begin
        out = JSON.parse(raw)
      rescue JSON::ParserError => e
        raise APIError.new(code: "INVALID_JSON", message: e.message, body: raw)
      end
      return out if out.is_a?(Array)
      return [] if out.nil?

      [out]
    end

    def run_batch(inputs)
      inputs = Array(inputs)
      return [] if inputs.empty?

      concurrency = [@concurrency.to_i, 1].max
      out = Array.new(inputs.length)
      first_err = nil
      err_mutex = Mutex.new
      queue = Queue.new
      inputs.each_with_index { |q, i| queue << [i, q] }

      workers = [concurrency, inputs.length].min.times.map do
        Thread.new do
          loop do
            break if err_mutex.synchronize { first_err }

            begin
              i, q = queue.pop(true)
            rescue ThreadError
              break
            end

            begin
              out[i] = yield(q)
            rescue StandardError => e
              err_mutex.synchronize { first_err ||= e }
            end
          end
        end
      end

      workers.each(&:join)
      raise first_err if first_err

      out
    end
  end
end
