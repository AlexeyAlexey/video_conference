---
name: stream-server-admin-api-auth
description: Recipe for authorizing API requests to the StreamServerAdminPortal — X-API-Key secrets with ssak_/aak_ prefixes, the ApiKeyAuth plug, the :api_credential assign, and how to add a new authenticated endpoint or issue a credential. Use whenever adding a route to the portal's [:api, ApiKeyAuth] scope, minting a stream server or application API key, or writing a client/test that calls a portal API endpoint.
---

# Authorizing StreamServerAdminPortal API requests

> **Scope:** this recipe applies to the `StreamServerAdminPortal` router's
> `:api` pipeline (`lib/video_conference_web/stream_server_admin_portal/router.ex`).
> The main router forwards `"/stream-server-admin"` to that router, so public
> URLs look like `/stream-server-admin/api/...` but routes inside the portal
> router are defined **without** the prefix (requests arrive stripped).

## The client contract

Callers authenticate with a single header — no session, no body credentials:

```
X-API-Key: <secret>
```

The secret has the form `env_prefix <> "_" <> prefix_id <> "_" <> random`:

- `ssak_` — a **stream server** credential (`stream_server_api_keys` table)
- `aak_` — an **application** credential (`application_api_keys` table)
- `prefix_id` is a UUID; `random` is `Base.url_encode64/2` of 32 crypto bytes
  (43 chars, no padding). Example:
  `ssak_3f6b8f0a-...-d1c2_AbCdEf...` (prefix_id is a full UUID)

The `env_prefix` is the **scope selector**: it decides which credential table
the plug queries, not which endpoint may be called — that decision belongs to
the controller (see below).

```elixir
# Elixir client (Req is the project's HTTP client)
Req.get!(
  "https://host/stream-server-admin/api/stream-server/public-key",
  params: [application_id: app_id, public_key_id: key_id],
  headers: [{"x-api-key", secret}]
)
```

```bash
curl -H "X-API-Key: ssak_<uuid>_<random>" \
  "https://host/stream-server-admin/api/stream-server/public-key?application_id=...&public_key_id=..."
```

## What ApiKeyAuth does

`VideoConferenceWeb.StreamServerAdminPortal.ApiKeyAuth`
(`lib/video_conference_web/stream_server_admin_portal/api_key_auth.ex`) is a
`Plug` piped into the `:api` scope. On each request it:

1. Reads `x-api-key` — anything but exactly one header value is a 401.
2. Splits the secret on `"_"` into `[env_prefix, prefix_id, random]` and
   casts `prefix_id` as `Ecto.UUID`.
3. Looks up the credential by its stored `prefix` column
   (`env_prefix <> "_" <> prefix_id`):
   - `"ssak"` -> `StreamServers.get_stream_server_api_key_by_prefix/1`
   - `"aak"` -> `Applications.get_api_key_by_prefix/1`
   - anything else -> treated as a miss
4. Requires `credential.enabled == true`.
5. Verifies the full secret with `ApiKeySecret.verify/2` (bcrypt) against
   `credential.hashed_api_key`.

On success it assigns `conn.assigns.api_credential` as:

- `{:stream_server, %StreamServers.ApiKey{}}` for `ssak_` secrets
- `{:application, %Applications.ApiKey{}}` for `aak_` secrets

**Every** failure — missing header, malformed secret, unknown prefix, disabled
credential, wrong random part — halts with the same response:

```json
401 {"errors": {"detail": "Unauthorized"}}
```

## Adding a new authenticated endpoint

1. Add the route inside the existing API-key scope of the portal router —
   remember paths are stripped, so `/api/...` not `/stream-server-admin/api/...`:

   ```elixir
   scope "/", VideoConferenceWeb.StreamServerAdminPortal do
     pipe_through [:api, ApiKeyAuth]

     get "/api/stream-server/public-key", PublicKeyController, :show
   end
   ```

2. In the controller, pattern-match `conn.assigns.api_credential` — the plug
   **authenticates**, the endpoint **authorizes**. If the endpoint is only for
   stream servers, reject the `{:application, _}` tuple (the reference
   implementation, `PublicKeyController.show/2`, maps that to `:unauthorized`
   and performs resource checks like
   `StreamServers.assigned_to_application?/2` on top).

3. Return errors as `%{errors: %{detail: ...}}` with a real status
   (`Plug.Conn.Status.code/1` + `reason_phrase/1`), like
   `PublicKeyController.error/2` — don't reuse the plug's fixed 401 body for
   domain failures; use 400/403/404 as appropriate.

## Issuing a credential

Secrets are minted only by the context create functions — never hand-build one:

- `StreamServers.create_stream_server_api_key/1` -> `ssak_` secret
- `Applications.create_api_key/1` -> `aak_` secret

Both return `{:ok, key}` where the virtual `key.plaintext_key` holds the
plaintext **once** — only `ApiKeySecret.hash/1`'s bcrypt output and the lookup
`prefix` are persisted. There is no way to recover or rotate a secret in
place; re-issue a new key and disable the old one. The admin UI surfaces the
plaintext once via `@new_key_secret` in `ApiKeysLive` (application keys) and
`StreamServerApiKeysLive` (stream server keys).

## Invariants

- **Plaintext is shown once** — the changesets never cast a secret, so it is
  immutable after creation. Treat loss as "issue a new key".
- **`env_prefix` selects the table, not the permission** — a valid `aak_`
  secret authenticates fine and still must be rejected by endpoints that
  require `{:stream_server, _}`. Always assert this in tests.
- **Prefix misses cost the same as hits** — `ApiKeyAuth` runs
  `Bcrypt.no_user_verify()` on an unknown prefix so valid
  `env_prefix_prefixId` prefixes can't be enumerated by timing. Keep it that
  way if you touch the plug.
- **Disabled and unknown credentials are indistinguishable** — both return the
  identical 401 body; don't leak which case it was.
- **Header only** — the plug reads `x-api-key` exclusively. Never accept the
  secret via query params or request body (URLs get logged).
- **`prefix` is unique per table** — collisions are impossible because
  `prefix_id` is a fresh `Ecto.UUID.generate()` per key.

## Testing

Fixtures return `{key, plaintext_secret}` because the secret is only available
at creation time:

```elixir
import VideoConference.StreamServerAdminPortalFixtures

{api_key, secret} = stream_server_api_key_with_secret_fixture(stream_server)
{_app_key, aak_secret} = api_key_with_secret_fixture(application)

conn =
  conn
  |> put_req_header("x-api-key", secret)
  |> get("/stream-server-admin/api/stream-server/public-key", params)
```

Cover at minimum: happy path, missing header (401), malformed/wrong secret
(401), disabled credential (401), wrong-scope credential (a `aak_` secret
against a stream-server-only endpoint), and the endpoint's own authorization
failures (e.g. unassigned server -> 403).

Reference tests: `api_key_auth_test.exs` (plug-level) and
`public_key_controller_test.exs` (request-level, including the
cross-credential and disabled-key cases).
