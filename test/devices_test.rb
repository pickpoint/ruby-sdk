# frozen_string_literal: true

require_relative "test_helper"

class DevicesTest < Minitest::Test
  def test_list
    base = "https://api.test"
    stub_request(:get, "#{base}/v2/devices")
      .with(query: { "skip" => "1", "take" => "25", "search" => "car", "idle" => "1" })
      .to_return(
        status: 200,
        body: {
          "data" => [{
            "uid" => "d1",
            "name" => "n",
            "tracksCount" => 3,
            "createdAt" => "t"
          }],
          "total" => 1
        }.to_json
      )

    result = client(base: base, api_key: "k").devices.list(
      Pickpoint::DeviceListQuery.new(skip: 1, take: 25, search: "car", idle: true)
    )
    assert_equal 1, result.total
    assert_equal "d1", result.data[0].uid
    assert_equal 3, result.data[0].tracks_count
  end

  def test_get_create_update_delete
    base = "https://api.test"
    stub_request(:get, "#{base}/v2/devices/uid%2F1")
      .to_return(status: 200, body: { "uid" => "uid/1", "name" => "A" }.to_json)
    stub_request(:post, "#{base}/v2/devices")
      .with(body: hash_including("name" => "A", "type" => "car"))
      .to_return(status: 200, body: { "uid" => "new", "name" => "A", "type" => "car" }.to_json)
    stub_request(:patch, "#{base}/v2/devices/new")
      .with(body: hash_including("name" => "B", "type" => "car"))
      .to_return(status: 200, body: { "uid" => "new", "name" => "B" }.to_json)
    stub_request(:delete, "#{base}/v2/devices/new")
      .to_return(status: 204, body: "")

    c = client(base: base, api_key: "k")
    assert_equal "uid/1", c.devices.get("uid/1").uid

    created = c.devices.create(Pickpoint::DeviceInput.new(name: "A", type: "car"))
    assert_equal "new", created.uid

    updated = c.devices.update("new", Pickpoint::DeviceInput.new(name: "B", type: "car"))
    assert_equal "B", updated.name

    assert_nil c.devices.delete("new")
  end

  def test_devices_404
    base = "https://api.test"
    stub_request(:get, "#{base}/v2/devices/missing")
      .to_return(status: 404, body: { "message" => "Device not found" }.to_json)

    err = assert_raises(Pickpoint::APIError) do
      client(base: base, api_key: "k").devices.get("missing")
    end
    assert err.not_found?
    assert_equal "NOT_FOUND", err.code
    assert_match(/Device not found/, err.message)
  end

  def test_devices_conflict_409
    base = "https://api.test"
    stub_request(:post, "#{base}/v2/devices/u1/command")
      .to_return(status: 409, body: { "message" => "device offline" }.to_json)

    err = assert_raises(Pickpoint::APIError) do
      client(base: base, api_key: "k").devices.command("u1", "x")
    end
    assert err.conflict?
  end

  def test_command_base64
    base = "https://api.test"
    stub_request(:post, "#{base}/v2/devices/uid-1/command")
      .with(body: { "payload" => "aGk=" }.to_json)
      .to_return(status: 200, body: { "delivered" => 1 }.to_json)

    out = client(base: base, api_key: "k").devices.command("uid-1", "hi")
    assert_equal 1, out.delivered
  end
end
