# frozen_string_literal: true

module Pickpoint
  # Unified public-api client (geocoding, address, routing, devices).
  # This gem does not include realtime tracking.
  class Client
    attr_reader :geocoding, :address, :routing, :devices, :concurrency

    def initialize(cfg)
      base = Transport.trim_slash(cfg.base_url || DEFAULT_BASE_URL)
      timeout = cfg.timeout && cfg.timeout.positive? ? cfg.timeout : DEFAULT_TIMEOUT
      http = Http.new(timeout: timeout, adapter: cfg.http_adapter)

      max_retries = cfg.max_retries && cfg.max_retries.positive? ? cfg.max_retries : DEFAULT_MAX_RETRIES
      retry_base = cfg.retry_base && cfg.retry_base.positive? ? cfg.retry_base : DEFAULT_RETRY_BASE
      retry_base = [retry_base, MIN_RETRY_BASE].max
      concurrency = cfg.concurrency && cfg.concurrency.positive? ? cfg.concurrency : DEFAULT_CONCURRENCY
      concurrency = [concurrency, MAX_CONCURRENCY].min

      auth = Auth.resolve(cfg, base, http)
      transport = Transport::Client.new(
        base_url: base,
        http: http,
        auth: auth,
        max_retries: max_retries,
        retry_base: retry_base
      )

      @concurrency = concurrency
      @geocoding = GeocodingService.new(transport, concurrency)
      @address = AddressService.new(transport)
      @routing = RoutingService.new(transport)
      @devices = DevicesService.new(transport)
    end

    # Flat shortcuts
    def forward(query) = geocoding.forward(query)
    def reverse(query) = geocoding.reverse(query)
    def lookup(query) = geocoding.lookup(query)
    def forward_batch(queries) = geocoding.forward_batch(queries)
    def reverse_batch(queries) = geocoding.reverse_batch(queries)
    def lookup_batch(queries) = geocoding.lookup_batch(queries)
    def search(query) = address.search(query)
    def route(body) = routing.route(body)
    def optimized_route(body) = routing.optimized(body)
    def matrix(body) = routing.matrix(body)
    def locate(body) = routing.locate(body)
    def elevation(body) = routing.elevation(body)
  end
end
