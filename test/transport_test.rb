# frozen_string_literal: true

require_relative "test_helper"

class TransportTest < Minitest::Test
  def test_retries_5xx_then_succeeds
    base = "https://api.test"
    hits = { n: 0 }
    stub_request(:get, %r{#{base}/v2/geocode/forward}).to_return do
      hits[:n] += 1
      if hits[:n] == 1
        { status: 503, body: "busy" }
      else
        { status: 200, body: [{ "ok" => 1 }].to_json }
      end
    end

    out = client(base: base, api_key: "k", max_retries: 3).forward("q" => "x")
    assert_equal 1, out[0]["ok"]
    assert_equal 2, hits[:n]
  end

  def test_exhausts_retries_on_5xx
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/address/search}).to_return(status: 500, body: "nope")

    err = assert_raises(Pickpoint::APIError) do
      client(base: base, api_key: "k", max_retries: 1).search("q" => "x")
    end
    assert_equal "SERVER_ERROR", err.code
    assert_equal 500, err.status
  end

  def test_address_search_400_throws
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/address/search})
      .to_return(status: 400, body: { "message" => "bad", "errorCode" => 400 }.to_json)

    err = assert_raises(Pickpoint::APIError) do
      client(base: base, api_key: "k").search("q" => "x")
    end
    assert_equal 400, err.status
    assert_equal "CLIENT_ERROR", err.code
    assert_match(/bad/, err.message)
  end

  def test_routing_400_throws
    base = "https://api.test"
    stub_request(:post, "#{base}/v2/route")
      .to_return(status: 400, body: { "message" => "bad" }.to_json)

    err = assert_raises(Pickpoint::APIError) do
      client(base: base, api_key: "k").route({})
    end
    assert_equal 400, err.status
  end

  def test_402_is_auth
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/address/search}).to_return(status: 402, body: "{}")

    err = assert_raises(Pickpoint::APIError) do
      client(base: base, api_key: "k").search("q" => "x")
    end
    assert err.auth?
  end

  def test_message_from_error_field
    base = "https://api.test"
    stub_request(:post, "#{base}/v2/route")
      .to_return(status: 400, body: { "error" => "nope" }.to_json)

    err = assert_raises(Pickpoint::APIError) do
      client(base: base, api_key: "k").route({})
    end
    assert_match(/nope/, err.message)
  end

  def test_network_error
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/address/search}).to_timeout

    err = assert_raises(Pickpoint::APIError) do
      client(base: base, api_key: "k", max_retries: 0).search("q" => "x")
    end
    assert_equal "NETWORK", err.code
  end
end
