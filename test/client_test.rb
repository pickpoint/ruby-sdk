# frozen_string_literal: true

require_relative "test_helper"

class ClientTest < Minitest::Test
  def test_invalid_config_no_auth
    err = assert_raises(Pickpoint::InvalidConfigError) do
      Pickpoint::Client.new(Pickpoint::Config.new(base_url: "https://api.test"))
    end
    assert_match(/auth required/, err.message)
  end

  def test_invalid_config_multiple_auth
    assert_raises(Pickpoint::InvalidConfigError) do
      Pickpoint::Client.new(
        Pickpoint::Config.new(api_key: "a", access_token: "b", base_url: "https://api.test")
      )
    end
  end

  def test_api_key_header
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/geocode/forward})
      .with(headers: { "x-api-key" => "k" })
      .to_return(status: 200, body: [{ "place" => 1 }].to_json)

    out = client(base: base, api_key: "k").forward("q" => "Berlin")
    assert_equal 1, out[0]["place"]
  end

  def test_access_token_bearer
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/geocode/forward})
      .with(headers: { "Authorization" => "Bearer tok" })
      .to_return(status: 200, body: [].to_json)

    client(base: base, access_token: "tok").forward("q" => "x")
  end

  def test_trims_trailing_slash_on_base_url
    base = "https://api.test"
    stub_request(:get, "#{base}/v2/geocode/forward")
      .with(query: hash_including("q" => "x"))
      .to_return(status: 200, body: [].to_json)

    client(base: "#{base}/", api_key: "k").forward("q" => "x")
  end

  def test_namespaced_and_flat_shortcuts
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/geocode/forward}).to_return(status: 200, body: [].to_json)
    stub_request(:get, %r{#{base}/v2/geocode/reverse}).to_return(status: 200, body: "null")
    stub_request(:get, %r{#{base}/v2/address/lookup}).to_return(status: 200, body: [].to_json)
    stub_request(:get, %r{#{base}/v2/address/search}).to_return(status: 200, body: { "features" => [] }.to_json)
    stub_request(:post, "#{base}/v2/route").to_return(status: 200, body: { "trip" => {} }.to_json)
    stub_request(:post, "#{base}/v2/route/optimized").to_return(status: 200, body: {}.to_json)
    stub_request(:post, "#{base}/v2/route/matrix").to_return(status: 200, body: {}.to_json)
    stub_request(:post, "#{base}/v2/route/locate").to_return(status: 200, body: {}.to_json)
    stub_request(:post, "#{base}/v2/route/elevation").to_return(status: 200, body: {}.to_json)

    c = client(base: base, api_key: "k")
    assert_equal [], c.forward("q" => "a")
    assert_nil c.reverse("lat" => "1", "lon" => "2")
    assert_equal [], c.lookup("osm_ids" => "N1")
    assert_equal [], c.search("q" => "x")["features"]
    assert_equal({}, c.route("costing" => "auto")["trip"])
    assert_equal({}, c.optimized_route({}))
    assert_equal({}, c.matrix({}))
    assert_equal({}, c.locate({}))
    assert_equal({}, c.elevation({}))

    assert_equal [], c.geocoding.forward("q" => "a")
    assert_equal({}, c.routing.route("costing" => "auto")["trip"])
    assert_equal([], c.address.search("q" => "x")["features"])
  end
end
