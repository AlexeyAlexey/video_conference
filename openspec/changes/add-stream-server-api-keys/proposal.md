# Proposal

## Why

Remote stream servers need their own credentials to authenticate with the
stream server admin portal — to fetch a public key by app id and public key
id, and to push their current state. API keys today belong only to
applications; there is no credential a physical stream server can present.
The portal needs a way to issue and manage per-server API keys.

## What Changes

- New `stream_server_api_keys` table and `StreamServers.ApiKey` schema:
  UUID primary key, required `stream_server_id` reference, non-unique
  required `name`, optional `description`, `enabled` flag, bcrypt-hashed
  secret, `lock_version` for optimistic concurrency, timestamps. Names are
  NOT unique within a server (unlike application API keys); only the hashed
  secret is unique per server.
- New shared `StreamServerAdminPortal.ApiKeySecret` module that owns secret
  generation (`ssak_`-prefixed) and hashing; `Applications.create_api_key/1`
  is refactored to use it so both scopes share one implementation.
- `StreamServers` context gains API key functions: list a server's keys,
  get one, create (returns the plaintext secret once), rename, edit
  description, enable, disable, and a changeset builder. Updates are
  guarded by `lock_version`. There is no delete and no event-store
  emission.
- New `StreamServerApiKeysLive` page at
  `/stream-server-admin/stream-servers/api-keys` (plus the
  `/stream-server-admin`-prefixed mirror route), index-only:
  - a required, searchable stream server filter whose options read
    "name (host)" — there is no "all servers" option; until a server is
    picked the page prompts to select one and the add button stays
    disabled; the choice is reflected in the `?stream_server_id=` URL
    param.
  - an "Add API key" button opening an event-driven modal with name,
    description, and enabled fields; the owning server is shown read-only
    as "name (host)" taken from the current filter.
  - a one-time secret banner after creation (copy + dismiss), same as the
    application API keys page.
  - a per-field-edited table: pencil opens a rename modal, pencil opens a
    description modal, and the enabled checkbox toggles immediately.
- The portal sidebar's "Stream servers" item gains an "API keys"
  sub-item, mirroring the Applications group.

## Capabilities

### New Capabilities

- `stream-server-api-keys`: per-stream-server API key credentials in the
  stream server admin portal — hashed-secret records, one-time secret
  display, the server-filtered admin page, and per-field management.

### Modified Capabilities

- `stream-server-admin-portal`: the "Portal navigation" requirement gains
  an "API keys" sub-item under the "Stream servers" sidebar item.

## Impact

- **Code**: `lib/video_conference/stream_server_admin_portal/` (new
  `api_key_secret.ex`, `stream_servers/api_key.ex`, extended
  `stream_servers.ex`, refactored `applications.ex`),
  `lib/video_conference_web/stream_server_admin_portal/` (new
  `live/stream_server_api_keys_live.ex`, `router.ex`,
  `admin_components.ex`)
- **Database**: new migration in `priv/stream_server_admin_portal_repo/migrations`
- **Behavior**: `Applications.create_api_key/1` return contract unchanged;
  only its internals move to the shared secret module. No events, no API
  key deletion, and no secret verification endpoint are added — consuming
  these keys for authentication is a separate change.
