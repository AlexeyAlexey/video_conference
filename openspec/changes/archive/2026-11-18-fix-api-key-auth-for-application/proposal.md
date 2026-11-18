# Proposal

## Why

An `aak_` API key belonging to a disabled application still authenticates
today: `ApiKeyAuth` only checks the key's own `enabled` flag and the
bcrypt hash, so the credential is assigned and only a per-endpoint
follow-up (`Applications.authenticated_application/1`) notices the
parent application is disabled. That leaves the enforcement of
"disabled applications cannot use the API" to every `aak_` endpoint
individually — a new endpoint that forgets the check would silently
authenticate a disabled application's credential.

## What Changes

- `Applications.get_api_key_by_prefix/1` gains a filter parameter;
  `:application_enabled` joins the parent application and requires
  it to be enabled, returning `{:error, :not_found}` for keys on
  disabled applications (same as an unknown prefix).
- `ApiKeyAuth` passes `:application_enabled` on the `"aak"`
  lookup, so a key on a disabled application fails authentication with
  401 — indistinguishable from an unknown prefix and covered by the
  same `Bcrypt.no_user_verify` timing equalization.
- **BREAKING** (API contract): the connection info endpoint previously
  answered disabled applications with 404; such requests now fail at
  the auth layer with 401.
- `Applications.authenticated_application/1` is left unchanged; its
  `enabled: true` filter becomes redundant but stays as
  defense-in-depth.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `stream-server-api`: the `X-API-Key` authentication requirement gains
  a rule that an `aak_` credential whose owning application is disabled
  is rejected with 401.
- `application-connection-info`: the "disabled application rejected"
  requirement changes from 404 (endpoint-level) to 401
  (authentication-level).

## Impact

- `lib/video_conference/stream_server_admin_portal/applications.ex` —
  `get_api_key_by_prefix/1` becomes `/2` accepting an
  `:application_enabled` filter.
- `lib/video_conference_web/stream_server_admin_portal/api_key_auth.ex`
  — the `"aak"` branch passes the option.
- Tests: `applications_test.exs` (option behavior),
  `api_key_auth_test.exs` (disabled-app key → 401),
  `connection_info_controller_test.exs` (disabled app → 401 instead of
  404).
