# Design

## Context

The stream server admin portal (`/stream-server-admin`) already provides
an isolated shell: its own Ecto repo
(`VideoConference.StreamServerAdminPortal.Repo`, SQLite, migrations under
`priv/stream_server_admin_portal_repo/migrations/`), forwarded router
with `/stream-server-admin`-prefixed mirror `live` routes, a collapsible
sidebar in `admin_components.ex`, and LiveViews laid out via
`Layouts.stream_server_admin`. Per proposal.md, this change adds
managed entities — applications and their API keys — inside that
portal. `bcrypt_elixir` is already a dependency. The admin portal's
`StreamServersLive` establishes the CRUD LiveView pattern
(`live_action` `:index`/`:new`/`:edit`, `push_patch`, `assign_form`),
and `DropdownComponent` is the required way to render select fields.

## Goals / Non-Goals

**Goals:**

- Applications and API keys persisted in the portal database with UUID
  primary keys and the uniqueness rules from the spec delta.
- Portal CRUD UI for both entities, API keys grouped by application,
  responsive, sidebar navigation extended.
- API key secrets generated at creation, displayed once, stored only as
  bcrypt hashes.
- Deploy-time seeding of the default application/API key from env vars.

**Non-Goals:**

- The REST API that consumes API keys (future change — no auth plug, no
  endpoints, no key-verification hot path designed here).
- API key regeneration/rotation UI (delete-and-recreate suffices).
- Any change to `/admin`, the main repo, or the app database.

## Decisions

### D1: Portal repo, `binary_id` UUID keys

Tables `applications` and `api_keys` go in
`priv/stream_server_admin_portal_repo/migrations/` — portal data stays
in the dedicated database, honoring the portal isolation spec. Both
schemas declare `@primary_key {:id, :binary_id, autogenerate: true}`;
`api_keys` adds `@foreign_key_type :binary_id` and
`belongs_to :application`. The migration creates the columns with
`add :id, :binary_id, primary_key: true` and
`add :application_id, references(:applications, type: :binary_id, on_delete: :delete_all)`,
so deleting an application removes its keys (spec requirement).

The user's `created_at` maps to Ecto's `inserted_at` (`timestamps()`),
matching every other table in the project.

Alternative: integer ids like the existing portal tables — rejected; the
request explicitly requires UUID primary keys.

### D2: `hashed_api_key` column, virtual plaintext field

The bcrypt hash is stored in `hashed_api_key` (`redact: true`), mirroring
`Admin.hashed_password`. The plaintext is never a persisted field: the
`ApiKey` schema has a virtual `plaintext_key` (`redact: true`) that the
context populates on the returned struct at creation so the LiveView can
display it once. The user's spec field `api_key` is realized as this
plaintext value at creation + `hashed_api_key` at rest.

The generated secret: `:crypto.strong_rand_bytes(32)` URL-safe base64
(`Base.url_encode64(padding: false)`), prefixed `ssak_` so leaked keys
are recognizable in logs/config scans (e.g.
`ssak_<43 chars>`). `Applications.create_api_key/2` generates the secret,
puts `Bcrypt.hash_pwd_salt(secret)` into `hashed_api_key`, and returns
`{:ok, api_key}` with `plaintext_key` set.

### D3: Uniqueness via DB constraints + changeset checks

- `applications.name`: `unique_index(:applications, [:name])` +
  `unsafe_validate_unique`/`unique_constraint` (same pattern as
  `Admin.email`).
- `api_keys.name` per app:
  `unique_index(:api_keys, [:application_id, :name])`.
- `api_keys` secret per app:
  `unique_index(:api_keys, [:application_id, :hashed_api_key])` —
  effectively guaranteed by random generation, but declared per the
  requirement.

### D4: Two LiveViews, `live_action` routing

`ApplicationsLive` (`/stream-server-admin/applications`,
actions `:index`/`:new`/`:edit`) and `ApiKeysLive`
(`/stream-server-admin/api-keys`, same actions) follow the
`StreamServersLive` pattern: `handle_params` → `apply_action`,
`assign_form`, `phx-change="validate"`/`phx-submit="save"`,
`push_patch` back to index, flash confirmations, `data-confirm`-style
delete. Enabled toggling is handled through the edit form's checkbox —
no separate toggle event needed.

`ApiKeysLive` renders the list grouped by application
(`Repo.preload(:api_keys)` on the app list, grouped sections in HEEx).
The create/edit form picks the parent application via
`DropdownComponent` (never a native `<select>` — broken popup position
in mobile Chrome per project skill), with
`on_change` → `handle_info` → `put_change(:application_id, id)` —
`id` arrives already a UUID string, no `String.to_integer` cast needed.

One-time display: after a successful create, `ApiKeysLive` assigns the
plaintext into `new_key_secret` and renders a dismissible notice (daisyUI
alert) on the index view; the assign is cleared on dismiss or any
subsequent navigation — the secret only ever lives in the socket assigns
of that response cycle.

Mirror routes: both pages get `/stream-server-admin`-prefixed mirror
`live` routes inside the same `live_session`, as the existing router
requires for LV `route_info` resolution.

### D5: Defaults seeded by a portal-repo migration

Following the `seed_default_admin` precedent, a migration reads
`DEFAULT_STREAM_SERVER_APP_ID` and `DEFAULT_STREAM_SERVER_API_KEY` via
`System.get_env/1` at migrate time and `insert_all`s the default
application ("Default App", env UUID, warning description, enabled) and
default API key ("Default API Key", `Bcrypt.hash_pwd_salt(env_key)`,
warning description, enabled) with `on_conflict: :nothing` for
idempotency. If `DEFAULT_STREAM_SERVER_APP_ID` is unset/invalid, a
generated UUID is used; if `DEFAULT_STREAM_SERVER_API_KEY` is unset, a
random secret is generated (its plaintext is never shown — admins
replace it with their own key). This keeps fresh dev/test setups working
while letting real deployments pin the defaults via env, and satisfies
"script run when deployed": portal migrations already run at deploy via
`VideoConference.Release.migrate` / `mix ecto.migrate`.

The env vars are added to `.env.example` and `.env.test.example` (and the
local `.env`/`.env.test` so tests and dev seeding exercise them).

### D6: New `Applications` context

`VideoConference.StreamServerAdminPortal.Applications` (with
`applications/` holding `Application` and `ApiKey` schemas) owns all
queries/changesets, using the portal `Repo`. It returns
`{:ok, api_key_with_plaintext}` from `create_api_key` and never exposes
the hash to the UI. Names/description/enabled editable on both entities;
the secret itself is immutable after creation.

## Risks / Trade-offs

- [bcrypt is expensive (~100ms) for key verification once the REST API
  exists, and there is no key-id lookup column] → acceptable now — the
  API is out of scope; if needed, a future change adds a key prefix/id
  column to locate the record before `Bcrypt.verify_pass`.
- [Deleting an application cascades to its API keys] → required
  behavior; the UI uses a confirm dialog naming the consequence.
- [Migration reads env vars once at migrate time — later env changes
  don't update seeded rows] → documented; `on_conflict: :nothing` keeps
  re-runs safe, and admins can edit/delete the defaults in the UI.
- [Plaintext secret in socket assigns briefly] → it must reach the
  browser once by design; `redact: true` fields keep it out of logs and
  `inspect` output.

## Migration Plan

1. `mix ecto.migrate` (dev/test via `dotenv -e .env*`; prod via
   `VideoConference.Release.migrate`) — creates both tables and seeds
   defaults. Set `DEFAULT_STREAM_SERVER_APP_ID` /
   `DEFAULT_STREAM_SERVER_API_KEY` before migrating to pin the defaults.
2. Rollback: `Ecto.Migrator` down on the portal repo drops the tables;
   the seed migration's `down/0` removes the seeded rows.

## Open Questions

- Exact list columns/actions per row on the two index pages — settled at
  implementation time against existing portal list markup; does not
  affect the spec.
