# Tasks

## 1. Data layer

- [x] 1.1 Add `SECRET_KEY_TO_ENCRYPT_PRIVATE_KEY` to `.env`, `.env.example`, `.env.test`, `.env.test.example`, and wire `config :video_conference, :stream_server_keys, encryption_secret: ...` in `config/dev.exs`, `config/test.exs`, and `config/runtime.exs` (raise in prod like `SECRET_KEY_BASE`); verify `Application.get_env(:video_conference, :stream_server_keys)[:encryption_secret]` is set in `iex`/`mix test`
- [x] 1.2 Create `AdminPortal.StreamServers.KeyEncryption` (`encrypt/1`, `decrypt/1` via `Plug.Crypto.MessageEncryptor` + SHA-256-derived enc/sign keys, raising on missing secret) and verify round-trip encrypt/decrypt and wrong-secret failure in unit tests
- [x] 1.3 Create migration `create_public_stream_server_keys` (`name`, `public_key_id`, `public_key`, `private_key`, `stream_server_id` FK, `disabled` default false, `description`, timestamps; composite unique index on `[:stream_server_id, :name]`) and verify `mix ecto.migrate` succeeds
- [x] 1.4 Create `AdminPortal.StreamServers.PublicStreamServerKey` schema with changeset (required `name`/`public_key`/`stream_server_id`, `private_key_pem` virtual field encrypted into `private_key`, required on insert and blank-keeps on update, composite `unsafe_validate_unique`/`unique_constraint`) and verify changeset tests cover each rule

## 2. Context

- [x] 2.1 Add `generate_key_pair/0` (RSA-2048 PEM pair via `JOSE.JWK`) and CRUD functions (`list_public_stream_server_keys/0`, `list_stream_servers_with_public_keys/0`, `get_public_stream_server_key!/1`, `create_public_stream_server_key/1`, `update_public_stream_server_key/2`, `delete_public_stream_server_key/1`, `change_public_stream_server_key/2`) to `AdminPortal.StreamServers`, plus `PublicStreamServerKeysFixtures`; verify context tests cover insert uniqueness, encryption at rest, blank-keep on update, and generation without `public_key_id`

## 3. Admin UI

- [x] 3.1 Add `PublicStreamServerKeysLive` (`:index`, `:new`, `:generate`, `:edit` actions): grouped-by-server list with page description, "No stream servers found" empty state, Add/Generate/Edit forms with stream server dropdown and masked private key field, delete with confirm, responsive `overflow-x-auto` tables; verify LiveView tests cover each spec scenario
- [x] 3.2 Add a Description column to the list tables: long descriptions render as a truncated `...` preview inside a clickable button that expands/collapses the full text (client-side `JS.toggle_class`, no server event); verify LiveView tests cover truncation and the expandable control
- [x] 3.3 Add routes `/stream-servers/keys`, `/stream-servers/keys/new`, `/stream-servers/keys/generate`, `/stream-servers/keys/:id/edit` plus `/admin`-prefixed mirror routes in `AdminPortal.Router`, and a "Public keys" sub-item under "Stream servers" in `AdminComponents.admin_sidebar`; verify unauthenticated redirect to admin sign-in and sidebar navigation in tests

## 4. Verification

- [x] 4.1 Run `dotenv -e .env.test mix precommit` and fix all failures
