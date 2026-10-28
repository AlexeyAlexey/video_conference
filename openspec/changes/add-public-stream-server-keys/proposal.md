# Proposal

## Why

The application shares a public signing key with each stream server, which
assigns it a `public_key_id`. That id identifies which public key the stream
server uses to verify the signed JWT the application presents when a
participant connects (audio/video/events). Today there is no place to store
or manage these keys — the single signing key lives only in an environment
variable. Admins need to keep one or more key pairs per stream server,
including keys generated in the app before the server assigns an id.

## What Changes

- New `public_stream_server_keys` table: `name`, `public_key_id` (nullable),
  `public_key`, `private_key` (encrypted at rest), `stream_server_id` (FK,
  required), `disabled` flag, `description`, timestamps. Unique on
  `name + stream_server_id`.
- New `PublicStreamServerKey` schema in the `AdminPortal.StreamServers`
  scope, plus context CRUD functions.
- Private keys are encrypted before save and decrypted only when needed,
  using `SECRET_KEY_TO_ENCRYPT_PRIVATE_KEY` from the environment.
- Key pair generation (RSA, via JOSE which is already a transitive dep):
  admins can generate a private/public key pair and save it without a
  `public_key_id` to fill in later.
- New admin page "Public keys" as a sub-item under "Stream servers" in the
  sidebar, listing keys grouped by stream server, with an explanatory
  description and a "No stream servers found" empty state.
- Two creation flows on that page: "Generate" (server dropdown, name,
  description — app creates the key pair) and "Add" (server dropdown, name,
  public key id, public key, private key — admin pastes existing material).
- Edit keeps the private key secret: never rendered; a blank field keeps the
  stored key, a new value replaces and re-encrypts it.
- Out of scope: how the stream server receives the public key or assigns
  `public_key_id`; which key is chosen when several are enabled; where
  `public_key_id` travels in the JWT; wiring signing into
  `ConnectionCredentials`/`AuthToken`. This change is storage + admin UI only.

## Capabilities

### New Capabilities

- `stream-server-public-keys`: Management of the application's per-stream-server
  public/private signing key pairs — their encrypted persistence, admin CRUD,
  key generation, and the grouped admin listing.

### Modified Capabilities

<!-- None: the sidebar sub-item and page behavior are owned by the new
     capability; existing stream-servers/admin-portal requirements do not
     change. -->

## Impact

- New migration `create_public_stream_server_keys`.
- New `VideoConference.AdminPortal.StreamServers.PublicStreamServerKey` schema
  and `KeyEncryption` helper; new functions on
  `VideoConference.AdminPortal.StreamServers`.
- New `VideoConferenceWeb.AdminPortal.PublicStreamServerKeysLive` plus
  `/admin/stream-servers/keys` routes (with `/admin/stream-servers/keys` mirror routes for LiveView
  resolution through the forwarded admin router) and a sidebar sub-item in
  `AdminComponents.admin_sidebar`.
- `SECRET_KEY_TO_ENCRYPT_PRIVATE_KEY` added to `.env`, `.env.example`,
  `.env.test`, `.env.test.example` and config files (required in prod).
- No new dependencies; uses `jose` (already pulled in by `joken`) and
  `Plug.Crypto` (already pulled in by Phoenix).
