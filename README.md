# pickpoint (Ruby SDK)

Official Ruby SDK for [Pickpoint](https://pickpoint.io) — geocoding, address search, routing, and device registry over HTTP.

| API | What it does |
|-----|----------------|
| **Geocoding** | Address ↔ coordinates (forward, reverse, place lookup) |
| **Address search** | Typeahead / autocomplete for address inputs |
| **Routing** | Routes, matrices, optimized multi-stop, elevation |
| **Devices** | Register / manage tracking devices over HTTP |

This gem covers the **public HTTP API only** (no realtime WebSocket / gRPC tracking client). Docs: [pickpoint.io/docs](https://pickpoint.io/docs).

Apache-2.0. Siblings: [`@pickpoint/sdk`](https://github.com/pickpoint/pickpoint-js), [`go-sdk`](https://github.com/pickpoint/go-sdk), [`python-sdk`](https://github.com/pickpoint/python-sdk), [`rust-sdk`](https://github.com/pickpoint/rust-sdk).

```bash
gem install pickpoint
# or in Gemfile:
# gem "pickpoint"
```

Requires Ruby **3.1+**. Zero runtime dependencies (stdlib `Net::HTTP` + `JSON`).

---

## Public API

One `Client`, one auth session, whole public HTTP surface:

```ruby
require "pickpoint"

pp = Pickpoint::Client.new(
  Pickpoint::Config.new(api_key: ENV.fetch("PICKPOINT_API_KEY"))
)

places = pp.forward("q" => "Berlin", "limit" => "5")
pp.reverse("lat" => "52.52", "lon" => "13.405")
pp.search("q" => "Alexanderplatz")
pp.route(
  "locations" => [
    { "lat" => 52.52, "lon" => 13.40 },
    { "lat" => 52.53, "lon" => 13.42 }
  ],
  "costing" => "auto"
)

devices = pp.devices.list
puts devices.total
```

### API map

| Method | HTTP | Notes |
|--------|------|--------|
| `forward` / `geocoding.forward` | `GET /v2/geocode/forward` | Nominatim-style; returns `Array` |
| `reverse` / `geocoding.reverse` | `GET /v2/geocode/reverse` | `Hash` or `nil` |
| `lookup` / `geocoding.lookup` | `GET /v2/address/lookup` | e.g. `osm_ids` |
| `forward_batch` / `reverse_batch` / `lookup_batch` | same | Geocoding **only**; conveyor ≤20 in flight |
| `search` / `address.search` | `GET /v2/address/search` | Photon autocomplete |
| `route` / `optimized_route` / `matrix` / `locate` / `elevation` | `POST /v2/route…` | Valhalla JSON body |
| `devices.list` / `get` / `create` / `update` / `delete` | `/v2/devices` | Typed structs |
| `devices.command` | `POST …/command` | Payload bytes (SDK base64-encodes) |
| `Pickpoint.mint_client_tokens` | `POST /v2/client-tokens` | Needs secret `api_key` |

Query params for geocode/address are plain `Hash` of strings (symbol keys are fine).

### Auth

Provide **exactly one** of:

| Field | Header | Use |
|-------|--------|-----|
| `api_key` | `x-api-key` | Backends, workers, CLIs |
| `client_auth` | `Authorization: Bearer` | Short-lived pair; auto-refresh |
| `access_token` | `Authorization: Bearer` | Static token, no refresh |

Keep the secret API key on the server. For client apps mint **client-tokens** and pass `client_auth`.

```ruby
pair = Pickpoint.mint_client_tokens(
  Pickpoint::Config.new(api_key: ENV.fetch("PICKPOINT_API_KEY")),
  scopes: %w[geocoding address routing devices],
  ttl_sec: 600
)

pp = Pickpoint::Client.new(
  Pickpoint::Config.new(
    client_auth: Pickpoint::ClientAuth.new(
      access_token: pair.access_token,
      refresh_token: pair.refresh_token,
      expires_at: pair.expires_at
    )
  )
)
```

Refresh behavior (same as Go/Python/JS):

1. Proactive refresh at **~50% of access TTL** (single-flight).
2. On HTTP **401**, one refresh + retry.
3. If refresh fails → `Pickpoint::APIError` with auth code.

### Config

```ruby
Pickpoint::Config.new(
  api_key: "…",
  base_url: "https://api.pickpoint.io", # default
  timeout: 30.0,
  max_retries: 3,
  retry_base: 1.0,
  concurrency: 20
)
```

| Constant | Value |
|----------|--------|
| `DEFAULT_BASE_URL` | `https://api.pickpoint.io` |
| `DEFAULT_TIMEOUT` | 30s |
| `DEFAULT_MAX_RETRIES` | 3 |
| `DEFAULT_RETRY_BASE` | 1s (`MIN_RETRY_BASE` = 0.2s) |
| `MAX_CONCURRENCY` | 20 |

---

## Development

```bash
bundle install
bundle exec rake test
```
