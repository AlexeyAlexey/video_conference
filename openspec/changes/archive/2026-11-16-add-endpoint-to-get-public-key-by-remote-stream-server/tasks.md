# Tasks

## 1. Context lookups

- [x] 1.1 Add `StreamServers.get_stream_server_api_key_by_prefix/1` (returns `%ApiKey{}` or `nil`) and `Applications.get_api_key_by_prefix/1`; verify context tests cover hit, miss, and that a disabled key is still returned (enabled check is the plug's job) via `dotenv -e .env.test mix test`
- [x] 1.2 Add a fixture helper producing a stream server API key plus its plaintext secret (and an application API key plus plaintext for the rejection path) in the portal fixtures; verify tests can authenticate with the returned secret

## 2. ApiKeyAuth plug

- [x] 2.1 Create `VideoConferenceWeb.StreamServerAdminPortal.ApiKeyAuth`: parse `X-API-Key` into `env_prefix`/`prefix_id`, dispatch `ssak`/`aak` to the lookup functions from 1.1, `ApiKeySecret.verify/2`, require `enabled`, assign `conn.assigns.api_credential` as `{:stream_server, key}` or `{:application, key}`; halt 401 JSON otherwise; run `Bcrypt.no_user_verify/0` on prefix-miss; verify plug tests cover each 401 path and both credential types
- [x] 2.2 Add `pipeline :api` (`plug :accepts, ["json"]`) to `VideoConferenceWeb.StreamServerAdminPortal.Router`; verify `mix compile` succeeds

## 3. Public key endpoint

- [x] 3.1 Add `GET /api/stream-server/public-key` → `PublicKeyController.show` in the portal router under `[:api, ApiKeyAuth]`; verify `mix phx.routes` lists it
- [x] 3.2 Implement `PublicKeyController.show`: reject non-`{:stream_server, _}` credentials with 401; validate `application_id`/`public_key_id` as UUIDs (400); check `application_stream_servers` assignment (403); fetch enabled `StreamServerPublicKey` by id + enabled application (404); render `{application_id, public_key_id, key}`; verify a `ConnCase` test covers 200 and every error branch (401 missing/bad/disabled/aak, 400, 403, 404 unknown/disabled key/app/cross-app key)

## 4. Final verification

- [x] 4.1 Run `dotenv -e .env.test mix precommit` and fix any warnings/test failures
