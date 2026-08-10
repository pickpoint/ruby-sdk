# frozen_string_literal: true

require "json"
require "uri"

module Pickpoint
  Device = Struct.new(
    :uid, :id, :name, :status, :description, :tracks_count, :type, :secret,
    :metadata, :created_at, :updated_at, :last_location,
    keyword_init: true
  ) do
    def self.from_hash(d)
      d = d.transform_keys(&:to_s)
      new(
        id: (d["id"] || 0).to_i,
        uid: (d["uid"] || "").to_s,
        name: (d["name"] || "").to_s,
        status: (d["status"] || "").to_s,
        description: d["description"],
        tracks_count: (d["tracksCount"] || 0).to_i,
        type: (d["type"] || "").to_s,
        secret: (d["secret"] || "").to_s,
        metadata: d["metadata"],
        created_at: (d["createdAt"] || "").to_s,
        updated_at: (d["updatedAt"] || "").to_s,
        last_location: d["lastLocation"]
      )
    end
  end

  DeviceInput = Struct.new(:name, :type, :description, :metadata, keyword_init: true) do
    def to_h
      out = { "name" => name, "type" => type }
      out["description"] = description unless description.nil?
      out["metadata"] = metadata unless metadata.nil?
      out
    end
  end

  DeviceListResult = Struct.new(:data, :total, keyword_init: true)
  DeviceListQuery = Struct.new(:skip, :take, :search, :idle, keyword_init: true)
  DeviceCommandResult = Struct.new(:delivered, keyword_init: true)

  class DevicesService
    def initialize(transport)
      @t = transport
    end

    def list(query = nil)
      q = query || DeviceListQuery.new
      params = {}
      params["skip"] = q.skip.to_s if q.skip && q.skip.to_i.positive?
      params["take"] = q.take.to_s if q.take && q.take.to_i.positive?
      params["search"] = q.search if q.search && !q.search.empty?
      params["idle"] = "1" if q.idle

      raw = @t.do(Transport::RequestOpts.new(method: "GET", path: "/v2/devices", query: params))
      body = JSON.parse(raw)
      DeviceListResult.new(
        data: Array(body["data"]).map { |x| Device.from_hash(x) },
        total: (body["total"] || 0).to_i
      )
    end

    def get(uid)
      path = "/v2/devices/#{URI.encode_www_form_component(uid)}"
      raw = @t.do(Transport::RequestOpts.new(method: "GET", path: path))
      Device.from_hash(JSON.parse(raw))
    end

    def create(input)
      raw = @t.do(Transport::RequestOpts.new(method: "POST", path: "/v2/devices", body: input.to_h))
      Device.from_hash(JSON.parse(raw))
    end

    def update(uid, input)
      path = "/v2/devices/#{URI.encode_www_form_component(uid)}"
      raw = @t.do(Transport::RequestOpts.new(method: "PATCH", path: path, body: input.to_h))
      Device.from_hash(JSON.parse(raw))
    end

    def delete(uid)
      path = "/v2/devices/#{URI.encode_www_form_component(uid)}"
      @t.do(Transport::RequestOpts.new(method: "DELETE", path: path))
      nil
    end

    def command(uid, payload)
      path = "/v2/devices/#{URI.encode_www_form_component(uid)}/command"
      # pack("m0") = strict Base64 (no newlines); avoids the base64 gem (not default since 3.4)
      b64 = [payload.to_s.b].pack("m0")
      raw = @t.do(
        Transport::RequestOpts.new(
          method: "POST",
          path: path,
          body: { "payload" => b64 }
        )
      )
      body = JSON.parse(raw)
      DeviceCommandResult.new(delivered: (body["delivered"] || 0).to_i)
    end
  end
end
