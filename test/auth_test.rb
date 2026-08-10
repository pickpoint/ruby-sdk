# frozen_string_literal: true

require_relative "test_helper"

class AuthTest < Minitest::Test
  def test_client_auth_refresh_on_401
    base = "https://api.test"
    calls = { i: 0 }

    stub_request(:post, "#{base}/v2/client-tokens/refresh")
      .to_return(
        status: 200,
        body: {
          "accessToken" => "access-2",
          "refreshToken" => "refresh-2",
          "expiresAt" => expires_at_ms(60)
        }.to_json
      )

    stub_request(:get, %r{#{base}/v2/geocode/forward}).to_return do |req|
      calls[:i] += 1
      auth = req.headers["Authorization"]
      if calls[:i] == 1
        assert_equal "Bearer access-1", auth
        { status: 401, body: "{}" }
      else
        assert_equal "Bearer access-2", auth
        { status: 200, body: [{ "ok" => true }].to_json }
      end
    end

    c = client(
      base: base,
      client_auth: Pickpoint::ClientAuth.new(
        access_token: "access-1",
        refresh_token: "refresh-1",
        expires_at: expires_at_ms(60)
      )
    )
    assert_equal 1, c.forward("q" => "a").length
  end

  def test_unauthorized_retry_exactly_once
    base = "https://api.test"
    hits = { n: 0 }

    stub_request(:post, "#{base}/v2/client-tokens/refresh")
      .to_return(
        status: 200,
        body: {
          "accessToken" => "a2",
          "refreshToken" => "r2",
          "expiresAt" => expires_at_ms(60)
        }.to_json
      )

    stub_request(:get, %r{#{base}/v2/geocode/forward}).to_return do
      hits[:n] += 1
      { status: 401, body: "{}" }
    end

    c = client(
      base: base,
      client_auth: Pickpoint::ClientAuth.new(
        access_token: "a1",
        refresh_token: "r1",
        expires_at: expires_at_ms(60)
      )
    )
    err = assert_raises(Pickpoint::APIError) { c.forward("q" => "x") }
    assert err.auth?
    assert_equal 2, hits[:n]
  end

  def test_api_key_401_does_not_refresh
    base = "https://api.test"
    stub_request(:get, %r{#{base}/v2/geocode/forward}).to_return(status: 401, body: "{}")

    err = assert_raises(Pickpoint::APIError) do
      client(base: base, api_key: "k").forward("q" => "x")
    end
    assert err.auth?
    assert_not_requested(:post, %r{.*/client-tokens/refresh})
  end

  def test_proactive_refresh_halfway_ttl
    base = "https://api.test"
    refreshed = { v: false }

    stub_request(:post, "#{base}/v2/client-tokens/refresh").to_return do
      refreshed[:v] = true
      {
        status: 200,
        body: {
          "accessToken" => "a2",
          "refreshToken" => "r2",
          "expiresAt" => expires_at_ms(60)
        }.to_json
      }
    end
    stub_request(:get, %r{#{base}/v2/geocode/forward}).to_return(status: 200, body: [].to_json)

    ttl = 0.2
    c = client(
      base: base,
      client_auth: Pickpoint::ClientAuth.new(
        access_token: "a1",
        refresh_token: "r1",
        expires_at: expires_at_ms(ttl)
      )
    )
    c.forward("q" => "early")
    refute refreshed[:v]

    sleep(ttl * 0.55 + 0.02)
    c.forward("q" => "late")
    assert refreshed[:v]
  end

  def test_single_flight_refresh
    base = "https://api.test"
    refreshes = { n: 0 }

    stub_request(:post, "#{base}/v2/client-tokens/refresh").to_return do
      refreshes[:n] += 1
      sleep(0.04)
      {
        status: 200,
        body: {
          "accessToken" => "access-fresh",
          "refreshToken" => "refresh-2",
          "expiresAt" => expires_at_ms(120)
        }.to_json
      }
    end
    stub_request(:get, %r{#{base}/v2/geocode/forward}).to_return do |req|
      assert_equal "Bearer access-fresh", req.headers["Authorization"]
      { status: 200, body: [{ "ok" => true }].to_json }
    end

    c = client(
      base: base,
      client_auth: Pickpoint::ClientAuth.new(
        access_token: "stale",
        refresh_token: "refresh-1",
        expires_at: expires_at_ms(0.08)
      )
    )
    sleep(0.05)

    threads = 4.times.map do
      Thread.new { c.forward("q" => "x") }
    end
    threads.each(&:join)
    assert_equal 1, refreshes[:n]
  end

  def test_incomplete_client_auth
    assert_raises(Pickpoint::InvalidConfigError) do
      client(
        base: "https://api.test",
        client_auth: Pickpoint::ClientAuth.new(
          access_token: "a",
          refresh_token: "",
          expires_at: expires_at_ms(60)
        )
      )
    end
  end

  def test_mint_client_tokens
    base = "https://api.test"
    stub_request(:post, "#{base}/v2/client-tokens")
      .with(
        headers: { "X-Api-Key" => "secret" },
        body: { "scopes" => ["geocoding"], "ttlSec" => 120 }
      )
      .to_return(
        status: 200,
        body: {
          "accessToken" => "a",
          "refreshToken" => "r",
          "expiresAt" => expires_at_ms(120),
          "expiresIn" => 120,
          "scopes" => ["geocoding"]
        }.to_json
      )

    pair = Pickpoint.mint_client_tokens(
      Pickpoint::Config.new(base_url: base, api_key: "secret"),
      scopes: ["geocoding"],
      ttl_sec: 120
    )
    assert_equal "a", pair.access_token
    assert_equal "r", pair.refresh_token
    assert_equal ["geocoding"], pair.scopes
  end

  def test_mint_empty_scopes
    base = "https://api.test"
    stub_request(:post, "#{base}/v2/client-tokens")
      .with { |req| JSON.parse(req.body)["scopes"] == [] }
      .to_return(
        status: 200,
        body: { "accessToken" => "a", "refreshToken" => "r", "expiresAt" => 1 }.to_json
      )

    pair = Pickpoint.mint_client_tokens(
      Pickpoint::Config.new(base_url: base, api_key: "secret")
    )
    assert_equal "a", pair.access_token
  end

  def test_mint_requires_api_key
    assert_raises(Pickpoint::InvalidConfigError) do
      Pickpoint.mint_client_tokens(Pickpoint::Config.new(access_token: "t"))
    end
  end
end
