# Design

## Context

The stream server admin portal already exposes a JSON API at
`/stream-server-admin/api/*` piped through `[:api, ApiKeyAuth]`.
`ApiKeyAuth` parses `X-API-Key`, dispatches on the secret's `env_prefix`
(`"ssak"` / `"aak"`), bcrypt-verifies, checks `enabled`, and assigns
`conn.assigns.api_credential` as `{:stream_server, key}` or
`{:application, key}`. The only existing endpoint,
`PublicKeyController.show`, is the style template: a `with` pipeline
returning `{:error, status}` mapped to
`json(%{errors: %{detail: reason}})`.

`StreamServer` carries `host`, `country` (lowercase ISO alpha-2 from
`Countries.codes()`), `cert_hash`, and `load` (0–100, volatile, updated
via `update_stream_server_load/2`, no events). Assignment to
applications lives in the `application_stream_servers` join table;
`StreamServers.assigned_to_application?/2` and
`filter_by_application/2` already query it. `load` currently has no
consumer — this endpoint is its first.

## Goals / Non-Goals

**Goals:**

- One GET endpoint resolving up to 4 distinct country codes to
  connection info in a single request and a single DB query.
- Server selection honors assignment + country and prefers the
  least-loaded server.
- Error statuses mirror the public-key endpoint's conventions.

**Non-Goals:**

- No write side effects — the endpoint does not reserve capacity, bump
  `load`, or record that a stream was placed. `load` stays telemetry
  written by the stream servers themselves.
- No server spreading: repeated codes resolve identically and collapse
  to one response entry; smarter scheduling is out of scope.
- No caching of resolution results.

## Decisions

- **Controller namespace**: `VideoConferenceWeb.StreamServerAdminPortal
  .Applications.ConnectionInfoController` under
  `scope "/api/application", VideoConferenceWeb.StreamServerAdminPortal
  .Applications` with `pipe_through [:api, ApiKeyAuth]` and
  `get "/connection-info", ConnectionInfoController, :show`. This adds a
  second API scope block rather than extending the existing
  `StreamServerAdminPortal` scope, keeping application-facing
  controllers grouped under the `Applications` alias.
- **GET with list param**: clients send
  `country_codes=us&country_codes=gb` (or `country_codes[]=...`
  brackets); Plug's query decoder produces
  `%{"country_codes" => [code, ...]}` — duplicates allowed, collapsing
  to at most 4 distinct codes. Chosen over POST-with-body because the
  call is a pure, side-effect-free read and stays cacheable/loggable
  as a URL.
- **`with` pipeline mirroring `PublicKeyController`**:
  `Applications.authenticated_application/1` (rejects `{:stream_server, _}`
  → 401, disabled or missing application → 404) — a shared context
  helper so every controller under the `Applications` scope resolves
  `conn.assigns.api_credential` the same way — `validate_params/1`
  (→ 400), then `Applications.connection_info(application_id:,
  country_codes:)` (→ 422 or `{:ok, info}` rendered by `json/2`).
- **Param validation**: plain function, not an Ecto changeset — the
  param is a flat string list; `validate_params` checks 1–4 distinct
  codes (`Enum.uniq/1` for the count only) of `~r/^[a-z]{2}$/i` shape
  and passes the raw list through — order and duplicates are the
  caller's, preserved into the response.
- **`Applications.ConnectionInfo` model**: resolution and response
  shaping live in `Applications.ConnectionInfo.execute(application_id:,
  country_codes:)`, reusable from any controller in the `Applications`
  scope, returning `[%{country_code:, url:, cert_hash?:}]` — one entry
  per requested code, request order, duplicates preserved — or
  `{:error, :unprocessable_entity, codes}`. The context façade
  `Applications.connection_info(application_id:, country_codes:)`
  delegates to it and is what controllers call.
- **One grouped query**: `Applications.stream_servers(application_id:,
  country_codes:, min_loaded: true)` — joins
  `application_stream_servers`, filters `country in ^country_codes`
  (an empty list means all countries), and groups by `country` at the
  database level: a single `min(s.load)` aggregate with SQLite's
  bare-column rule returns the whole least-loaded row per group as
  `%{country => server}`. `ConnectionInfo` looks each requested code
  up in the map. Beats N queries and a `DISTINCT ON` window for
  a table this size.
- **Selection semantics**: least `load` wins; servers tied on the
  lowest load resolve to whichever row SQLite picks, which is
  acceptable since `load` is volatile telemetry.
- **Country code format**: `country_code` must match
  `~r/^[a-z]{2}$/i` — case-insensitive, normalized to the stored
  lowercase shape via `String.downcase/1` inside
  `ConnectionInfo.execute`, so `"US"` resolves as `"us"` and the
  response carries the normalized code. Membership in
  `Countries.codes()` is NOT validated — a well-formed but unsupported
  code yields the 422 branch, same as a supported one with no servers.
- **422 error body**: `%{errors: %{detail: "No stream server
  available", country_codes: [...]}}` — extends the existing error
  shape with a `country_codes` field naming the unsatisfiable codes,
  since the caller submitted several independent codes.
- **Response construction**: built inside `ConnectionInfo` — a JSON
  array, one `%{country_code:, url: "https://" <> host}` entry per
  requested code in request order, with `cert_hash` added only when
  the picked server stores a non-empty value. An array (not a map)
  keeps duplicates addressable and order visible.

## Risks / Trade-offs

- **`load` staleness** → servers may report load infrequently or not at
  all; least-loaded degrades to alphabetical order, which is still
  deterministic and acceptable. No mitigation needed at this layer.
- **Race between resolution and connect** → the picked server's real
  load may differ by connect time; inherent to any lookup API, callers
  tolerate it.
- **GET query-length limits** → a handful of 2-char codes is far below
  any proxy limit; non-issue.
- **Codes appear in error body** → echoing caller-supplied codes in the
  422 body leaks nothing (codes are the caller's own input); internal
  server data stays out of the body — only codes and a generic detail.
