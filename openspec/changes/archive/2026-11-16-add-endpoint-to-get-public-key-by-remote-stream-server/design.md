# Design

## Context

Remote stream servers need to resolve an app-signed JWT's `kid` into
public key material held by the portal (`Applications.StreamServerPublicKey`,
record UUID = key id). Both credential tables —
`stream_server_api_keys` (`ssak_`) and `application_api_keys` (`aak_`) —
already carry a unique `prefix` column of the form
`env_prefix <> "_" <> prefix_id`, and `ApiKeySecret` already provides
`generate/2`, `prefix/2`, `hash/1`, and `verify/2`. What does not exist
yet: any lookup-by-prefix context function, any API-key plug, and any
`:api` pipeline in `VideoConferenceWeb.StreamServerAdminPortal.Router`
(today it only has `:browser`). The portal router is reached via
`forward "/stream-server-admin"` in the main router, so routes defined
there see the stripped path.

## Goals / Non-Goals

**Goals:**

- A reusable `X-API-Key` authentication plug for the portal that resolves
  a presented secret to a credential record (stream server key or
  application key) by `env_prefix` dispatch + `prefix` lookup + bcrypt
  verify + `enabled` check.
- `GET /stream-server-admin/api/stream-server/public-key` returning a public key for
  `application_id` + `public_key_id`, restricted to `ssak_` credentials
  whose stream server is assigned to the application.
- Uniform JSON errors: 401 / 403 / 404 per the spec.

**Non-Goals:**

- `aak_` credentials authenticating to this endpoint (rejected; the plug
  still recognizes the `aak` env_prefix so future app-facing endpoints
  can allow it).
- JWT verification itself — this endpoint only distributes key material.
- Rate limiting / auditing of API calls (deferred).
- Fixing the seeded default application key (see Risks).

## Decisions

### Route lives in the portal router under a new `:api` pipeline

`forward "/stream-server-admin"` strips the prefix, so the route is
declared as `get "/api/stream-server/public-key", PublicKeyController, :show`
inside the portal router — publicly reachable at
`/stream-server-admin/api/stream-server/public-key`. The portal router already imports
portal-auth helpers and all portal code (contexts, portal `Repo`) lives
under the `StreamServerAdminPortal` namespace; a matching
`pipeline :api do plug :accepts, ["json"] end` mirrors the main router's
convention. Alternative considered: mounting the route in the main
router — rejected, it would scatter portal-DB access across two web
layers for no benefit.

### One plug, three responsibilities split out

`VideoConferenceWeb.StreamServerAdminPortal.ApiKeyAuth` does only
authentication: read `X-API-Key`, parse
`env_prefix <> "_" <> rest`, look up the credential, verify, assign
`conn.assigns.api_credential`. Route-level authorization (ssak-only,
assignment check) is the controller's job — the plug stays reusable for
endpoints with different credential-type rules. Alternative: baking
"credential type allowed" into the plug via opts — acceptable later if a
second endpoint needs it; not worth it now.

Parsing: `env_prefix` is the first `_`-separated segment; `prefix_id` is
the UUID after it, and everything after the *next* `_` is ignored by the
lookup (it's the unhashed body — only bcrypt sees the full secret).
`"ssak"` → `stream_server_api_keys`, `"aak"` → `application_api_keys`;
anything else → reject without a DB hit.

### Lookup-by-prefix goes in the owning contexts

`StreamServers.get_stream_server_api_key_by_prefix/1` and
`Applications.get_api_key_by_prefix/1` (returning `nil` on miss, not
raising) — one-line queries on the unique `prefix` columns. The plug
then calls `ApiKeySecret.verify/2` on the presented secret vs
`hashed_api_key`.

**Timing mitigation**: when the prefix lookup misses, run
`Bcrypt.no_user_verify/0` (or verify against a constant dummy hash) so a
missing-prefix response is not measurably faster — otherwise an attacker
can enumerate valid `ssak_<uuid>` prefixes.

### Authorization: assignment join, 403 not 404

An authenticated `ssak_` credential resolves to a `StreamServer`; the
controller checks `application_stream_servers` for
`(stream_server_id, application_id)`. Denial is **403**, not 404 — the
application's existence is not secret to a credentialed caller, and 403
gives operators a debuggable distinction. Alternative considered: 404 to
hide existence — rejected as security theater here.

### Enabled checks on the whole chain

Return 404 when: the application does not exist, the application is
disabled, the key record does not exist, does not belong to the
application, or is disabled — one "not found" bucket so a disabled key
is indistinguishable from a deleted one. The credential's own `enabled`
flag failing is 401 (authentication problem), distinct from resource
state.

### Response body

```json
{"application_id": "…", "public_key_id": "…", "key": "…"}
```

`key` is the raw stored public material — the server already knows the
ids it asked for, but echoing them keeps responses self-describing in
logs.

## Risks / Trade-offs

- **Seeded default key can never authenticate.** The seed migration
  inserts the default application API key before the
  `application_api_keys` rename/prefix migration runs, so the backfill
  assigns it a random `aak_` prefix matching no secret; its generated
  secret is also `ssak_`-formatted, which dispatches to the wrong table.
  Harmless for this endpoint (it rejects `aak_` anyway) and the seed is
  a placeholder — noted as a known limitation; fixing it is a separate
  migration concern.
- **bcrypt cost per request** — inherent to hashed-secret verification;
  acceptable at expected call rates. → If call volume grows, cache
  verified credentials briefly or add per-IP throttling later.
- **Plug halts vs controller 403s** — credential-type rejection for this
  endpoint (`aak_` presented) happens in the controller as 401, keeping
  "who you are" (plug) separate from "what you may do" (controller).
- **UUID parse errors in params** — malformed `application_id` /
  `public_key_id` → 400 via param validation rather than letting Ecto
  raise.

## Migration Plan

Additive only: new pipeline, plug, controller, context functions. No DB
changes. Rollback = revert.
