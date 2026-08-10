# frozen_string_literal: true

require_relative "test_helper"

class GeocodingTest < Minitest::Test
  def test_geocode_empty_on_400
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/geocode/forward})
      .to_return(status: 400, body: { "message" => "bad" }.to_json)

    out = client(base: base, api_key: "k").forward("q" => "x")
    assert_equal [], out
  end

  def test_reverse_nil_on_404
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/geocode/reverse})
      .to_return(status: 404, body: { "message" => "none" }.to_json)

    assert_nil client(base: base, api_key: "k").reverse("lat" => "0", "lon" => "0")
  end

  def test_reverse_parses_object
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/geocode/reverse})
      .to_return(status: 200, body: { "display_name" => "Berlin" }.to_json)

    out = client(base: base, api_key: "k").reverse("lat" => "52.5", "lon" => "13.4")
    assert_equal "Berlin", out["display_name"]
  end

  def test_lookup
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/address/lookup})
      .with(query: hash_including("osm_ids" => "N1"))
      .to_return(status: 200, body: [{ "osm_id" => 1 }].to_json)

    out = client(base: base, api_key: "k").lookup("osm_ids" => "N1")
    assert_equal 1, out[0]["osm_id"]
  end

  def test_forward_batch
    base = "https://api.test"
    calls = { n: 0 }
    stub_request(:get, %r{#{base}/v2/geocode/forward}).to_return do
      calls[:n] += 1
      { status: 200, body: [{ "i" => calls[:n] }].to_json }
    end

    out = client(base: base, api_key: "k", concurrency: 5)
      .forward_batch([{ "q" => "a" }, { "q" => "b" }, { "q" => "c" }])
    assert_equal 3, out.length
    assert_equal 3, calls[:n]
  end

  def test_batch_preserves_order
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/geocode/forward}).to_return do |req|
      q = URI.decode_www_form(req.uri.query || "").to_h["q"]
      if q == "slow"
        sleep(0.06)
        { status: 200, body: [{ "id" => "slow" }].to_json }
      else
        { status: 200, body: [{ "id" => "fast" }].to_json }
      end
    end

    out = client(base: base, api_key: "k", concurrency: 10).forward_batch(
      [{ "q" => "slow" }, { "q" => "fast1" }, { "q" => "fast2" }]
    )
    assert_equal "slow", out[0][0]["id"]
    assert_equal "fast", out[1][0]["id"]
  end

  def test_batch_respects_concurrency
    base = "https://api.test"
    inflight = { n: 0, max: 0 }
    mu = Mutex.new

    stub_request(:get, %r{#{base}/v2/geocode/forward}).to_return do
      mu.synchronize do
        inflight[:n] += 1
        inflight[:max] = [inflight[:max], inflight[:n]].max
      end
      sleep(0.02)
      mu.synchronize { inflight[:n] -= 1 }
      { status: 200, body: [{ "ok" => true }].to_json }
    end

    qs = 12.times.map { { "q" => "x" } }
    out = client(base: base, api_key: "k", concurrency: 4).forward_batch(qs)
    assert_equal 12, out.length
    assert_operator inflight[:max], :<=, 4
  end

  def test_batch_abort_on_403
    base = "https://api.test"
    hits = { n: 0 }
    mu = Mutex.new

    stub_request(:get, %r{#{base}/v2/geocode/forward}).to_return do |req|
      mu.synchronize { hits[:n] += 1 }
      q = URI.decode_www_form(req.uri.query || "").to_h["q"]
      if q == "bad"
        { status: 403, body: "{}" }
      else
        sleep(0.08)
        { status: 200, body: [{ "ok" => true }].to_json }
      end
    end

    err = assert_raises(Pickpoint::APIError) do
      client(base: base, api_key: "k", concurrency: 4).forward_batch(
        [
          { "q" => "bad" }, { "q" => "a" }, { "q" => "b" },
          { "q" => "c" }, { "q" => "d" }, { "q" => "e" }
        ]
      )
    end
    assert err.auth?
    assert_operator hits[:n], :<, 6
  end

  def test_batch_empty
    assert_equal [], client(base: "https://api.test", api_key: "k").forward_batch([])
  end

  def test_reverse_and_lookup_batch
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/geocode/reverse})
      .to_return(status: 200, body: { "ok" => true }.to_json)
    stub_request(:get, %r{#{base}/v2/address/lookup})
      .to_return(status: 200, body: [{ "ok" => true }].to_json)

    c = client(base: base, api_key: "k")
    rev = c.reverse_batch([{ "lat" => "1", "lon" => "2" }, { "lat" => "3", "lon" => "4" }])
    assert_equal 2, rev.length
    assert_equal true, rev[0]["ok"]

    look = c.lookup_batch([{ "osm_ids" => "N1" }])
    assert_equal 1, look[0].length
  end
end
