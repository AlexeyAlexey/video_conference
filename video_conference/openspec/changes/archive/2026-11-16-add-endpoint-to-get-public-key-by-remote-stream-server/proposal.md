# Proposal

## Why

Remote stream servers receive JWTs signed by applications and must resolve
the token's key id (`kid`) into public key material to verify the
signature. The portal already stores that material
(`StreamServerPublicKey`, whose record UUID is the key id) and already
issues `ssak_` API keys to stream servers — but there is no way for a
server to fetch a key. This is the first remote-facing endpoint on the
portal; later ones (e.g. pushing server state) will reuse the same
authentication.

## What Changes

- New `:api` pipeline and an `ApiKeyAuth` plug in the stream server admin
  portal router: reads the `X-API-Key` header, dispatches on the secret's
  `env_prefix` to pick the credential table, looks the credential up by
  its stored `prefix`, verifies the secret with bcrypt, and requires the
  credential to be enabled. The plug is generic so future endpoints reuse
  it; this endpoint accepts only `ssak_` credentials.
- New endpoint `GET /stream-server-admin/api/stream-server/public-key` accepting
  `application_id` and `public_key_id` params. It returns the public key
  material only when the authenticated stream server is assigned to the
  requested application (`application_stream_servers`) and the key record
  exists, belongs to that application, and is enabled.
- JSON error responses: 401 for missing/invalid/disabled/wrong-type
  credentials, 403 for an authenticated server not assigned to the
  application, 404 for an unknown or disabled application/public key.

## Capabilities

### New Capabilities

- `stream-server-api`: the REST API the portal exposes to remote stream
  servers — `ssak_` API-key authentication over `X-API-Key` and the
  public-key resolution endpoint, including its assignment-scoped
  authorization.

### Modified Capabilities

(none — `application_api_keys.prefix` and `stream_server_api_keys` already
exist; this change only consumes them)

## Impact

- `VideoConferenceWeb.StreamServerAdminPortal.Router`: new `:api`
  pipeline and route.
- New plug module (e.g.
  `VideoConferenceWeb.StreamServerAdminPortal.ApiKeyAuth`) plus context
  lookup-by-prefix functions in `StreamServers` (and `Applications` for
  `aak_` dispatch completeness).
- New controller under
  `lib/video_conference_web/stream_server_admin_portal/controllers/`.
- No schema or migration changes.
