# Design

## Context

See proposal.md for motivation. Stream servers are managed in the admin
portal (`AdminPortal.StreamServers` context + `StreamServersLive`). JWT
signing for stream-server connections exists (`TelephoneSwitchboard.AuthToken`,
RS256 via Joken/JOSE) but is explicitly untouched by this change. The sidebar
already supports sub-items (see "Change password" under "Settings" in
`AdminComponents.admin_sidebar`).

## Goals / Non-Goals

**Goals:**
- Persist per-stream-server key pairs with the private key encrypted at rest.
- Admin CRUD + generate flows on a single grouped "Public keys" page.
- Zero new dependencies.

**Non-Goals:**
- Key selection at connect time, `kid`/claim placement in JWTs, and any
  wiring into `ConnectionCredentials`/`AuthToken`.
- How the stream server receives the public key or assigns `public_key_id`.

## Decisions

- **Module placement**: `AdminPortal.StreamServers.PublicStreamServerKey`
  schema and `AdminPortal.StreamServers.KeyEncryption` helper; CRUD functions
  on the existing `AdminPortal.StreamServers` context. Keeps the directory +
  its keys in one context, matching `StreamServers.StreamServer` and
  `StreamServers.Countries`.

- **Encryption**: `Plug.Crypto.MessageEncryptor.encrypt/3` (authenticated
  AES-256-GCM, already in the dep tree via Phoenix). The env secret is an
  arbitrary string, so derive fixed-size keys with SHA-256:
  `key = :crypto.hash(:sha256, "enc:" <> secret)` for the encryption key and
  `:crypto.hash(:sha256, "sig:" <> secret)` for the signing key. Stored
  `private_key` holds the opaque encrypted binary (base64 output of
  `MessageEncryptor`). Alternatives: `:crypto.crypto_one_time` by hand (more
  code, same result), `cloak`/`vault` (new dependency — rejected).

- **Encryption secret config**: `SECRET_KEY_TO_ENCRYPT_PRIVATE_KEY` read via
  `System.get_env` into `config :video_conference, :stream_server_keys` in
  `dev.exs`/`test.exs` (dev/test defaults are fine since `.env*` provides
  values via `dotenv`) and required via `raise` in `runtime.exs` prod block,
  matching `SECRET_KEY_BASE`/`TELEPHONE_SWITCHBOARD_PRIVET_KEY` handling.
  Missing secret at use time raises a clear error rather than saving
  unencrypted data.

- **Secret field in the schema**: column `private_key` stores ciphertext; a
  virtual `private_key_pem` field receives form input (mirrors the
  `cert_hash` virtual-field pattern in `StreamServer`). The changeset
  encrypts a non-blank `private_key_pem` into `private_key`; a blank
  `private_key_pem` on update means "keep". On insert, `private_key_pem` is
  required — enforced by a changeset validation, since requiredness differs
  between insert and update.

- **Uniqueness**: composite `unique_index(:public_stream_server_keys,
  [:stream_server_id, :name])` plus `unsafe_validate_unique` +
  `unique_constraint` in the changeset, matching existing error UX.

- **Key generation**: `JOSE.JWK.generate_key({:rsa, 2048})` then
  `JOSE.JWK.to_pem` for public/private PEM — `jose` is already a transitive
  dep of `joken`, and RS256/2048 matches the existing `AuthToken` key.
  Generation happens in the context (`generate_key_pair/0` or as part of
  `create_public_stream_server_key`), not the LiveView.

- **Page shape**: one `PublicStreamServerKeysLive` with live actions
  `:index`, `:new` (Add form), `:generate` (Generate form), `:edit` —
  mirroring `StreamServersLive`. Routes `/stream-servers/keys`, `/stream-servers/keys/new`,
  `/stream-servers/keys/generate`, `/stream-servers/keys/:id/edit` in the admin router plus `/admin`-prefixed
  mirror routes (required for LiveView `route_info` resolution through the
  forwarded router — see the note in `admin_portal/router.ex`). Sidebar gets
  a nested `<ul>` under "Stream servers" like the Settings/Change-password
  pattern.

- **Grouped list**: `list_stream_servers_with_public_keys()` returns servers
  (ordered by name) with keys preloaded (ordered by name). The page renders a
  section per server. "No stream servers found" renders when the list is
  empty.

- **Editing `public_key`**: allowed via textarea (it is not secret and may
  need correction), while `private_key` stays write-only/masked.

## Risks / Trade-offs

- **Env var naming**: `SECRET_KEY_TO_ENCRYPT_PRIVATE_KEY` must exist in
  `.env`/`.env.test`; missing in prod raises at boot — desired fail-fast.
- **Rotation**: changing the secret orphans existing encrypted keys →
  documented limitation; re-save keys after rotating.
- **Private key in transit**: submitted plaintext travels inside the normal
  form post over TLS; it is never rendered back — acceptable for an
  authenticated admin portal.
- **RSA-2048 fixed**: matches existing signing key; configurable size adds
  complexity for no current need.
