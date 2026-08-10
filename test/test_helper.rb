# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "webmock/minitest"
require "json"
require "pickpoint"

module TestHelpers
  def expires_at_ms(from_now)
    ((Time.now.to_f + from_now) * 1000).to_i
  end

  def client(base:, **opts)
    Pickpoint::Client.new(
      Pickpoint::Config.new(
        base_url: base,
        retry_base: Pickpoint::MIN_RETRY_BASE,
        **opts
      )
    )
  end
end

class Minitest::Test
  include TestHelpers
end
