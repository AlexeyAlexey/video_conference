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

- One GET endpoint resolving up to 4 named streams to connection info
  in a single request and a single DB query.
- Server selection honors assignment + country and prefers the
  least-loaded server.
- Error statuses mirror the public-key endpoint's conventions.

**Non-Goals:**

- No write side effects — the endpoint does not reserve capacity, bump
  `load`, or record that a stream was placed. `load` stays telemetry
  written by the stream servers themselves.
- No per-stream server spreading: identical `country_code`s resolve
  identically; smarter scheduling is out of scope.
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
- **GET with bracket params**: clients send
  `streams[][name]=video&streams[][country_code]=US`; Plug's query
  decoder produces the `[%{"name" => ..., "country_code" => ...}]` list
  directly. Chosen over POST-with-body because the call is a pure,
  side-effect-free read and stays cacheable/loggable as a URL.
- **`with` pipeline mirroring `PublicKeyController`**:
  `application_credential/1` (reject `{:stream_server, _}` → 401),
  `ensure_application/1` (`Applications.enabled_application?/1` → 404),
  `validate_params/1` (→ 400), `resolve/2` (→ 422), then `json/2`.
- **Param validation**: plain function, not an Ecto changeset — entries
  are ad-hoc maps with a dedupe step and a ≤20-char name rule; a
  schemaless `validate_params` returning `{:ok, [{name, code}, ...]}`
  is smaller than an embedded schema. Dedup by name with first
  occurrence winning (`Enum.uniq_by` on the validated list preserves
  order).
- **One grouped query**: fetch all servers assigned to the application —
  `Repo.all(from s in StreamServer, join: j in ApplicationStreamServer,
  ..., order_by: [asc: s.load, asc: s.name])` — then
  `Enum.group_by(& &1.country)` and take the first entry per requested
  code. No `country in ^codes` filter: the reserved `"any"` needs the
  global least-loaded server anyway, so the full assigned list is
  required regardless. Beats N queries and a `DISTINCT ON` window for a
  table this size.
- **Selection semantics**: `ORDER BY load ASC, name ASC` — least loaded,
  deterministic tie-break by name so repeated calls and same-country
  names are stable. `country_code: "any"` resolves to the first element
  of the whole ordered list (any country). Random was rejected: it makes
  tests flaky and gives no benefit while `load` is meant to drive
  placement.
- **Country code format**: `country_code` must be the literal `"any"`
  or match `~r/^[a-z]{2}$/` — the same lowercase ISO alpha-2 shape stored
  on `StreamServer.country`. No case folding: `"US"` is a 400 format
  violation, not a normalized match. Membership in `Countries.codes()`
  is NOT validated — a well-formed but unsupported code yields the 422
  branch, same as a supported one with no servers. `"any"` is reserved
  on `country_code` only; a stream *named* `"any"` stays legal.
- **422 error body**: `%{errors: %{detail: "No stream server
  available", streams: [...]}}` — extends the existing error shape with
  a `streams` field naming the unsatisfiable names (all names sharing a
  failed code), since the caller submitted up to 4 independent
  requests.
- **Response construction**: `Map.new(resolutions, fn {name, server} ->
  {name, maybe_put_cert_hash(%{url: "https://" <> server.host},
  server)} end)`; `cert_hash` key omitted when `nil` or `""`.

## Risks / Trade-offs

- **`load` staleness** → servers may report load infrequently or not at
  all; least-loaded degrades to alphabetical order, which is still
  deterministic and acceptable. No mitigation needed at this layer.
- **Race between resolution and connect** → the picked server's real
  load may differ by connect time; inherent to any lookup API, callers
  tolerate it.
- **GET query-length limits** → 4 entries × ~40 chars is far below any
  proxy limit; non-issue.
- **Name appears in error body** → echoing caller-supplied names in the
  422 body leaks nothing (names are the caller's own input) but the
  body should not echo `country_code` back alongside internal server
  data — it doesn't, only names and a generic detail.
- **Case sensitivity of `name` keys** → `"Video"` and `"video"` are
  distinct keys; documented behavior, no normalization applied.
