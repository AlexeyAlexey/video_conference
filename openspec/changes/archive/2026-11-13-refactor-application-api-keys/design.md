# Design

## Context

The stream server admin portal (own SQLite Repo, migrations under
`priv/stream_server_admin_portal_repo`) has two API key scopes.
`StreamServers.ApiKey` (`stream_server_api_keys`) is the newer shape:
unique `prefix` holding `"ssak_" <> prefix_id`, bcrypt `hashed_api_key`,
`lock_version`, per-field changesets, an index-only LiveView with a
required owner filter, modal add, and per-field editing.
`Applications.ApiKey` still sits in the older `api_keys` table: no
`prefix`, no `lock_version`, unique `(application_id, name)`, a grouped
"all applications" page with `/new` and `/:id/edit` routes and row
deletion. The shared `ApiKeySecret` module already produces
`env_prefix <> "_" <> prefix_id <> "_" <> <random>` secrets for both
scopes — `create_api_key/1` already passes `"aak"` — but the `aak_<id>`
prefix is generated and discarded instead of stored.

See proposal.md — Why for motivation.

## Goals / Non-Goals

**Goals:**

- `application_api_keys` table with `prefix` and `lock_version`, same
  columns and index shape as `stream_server_api_keys`.
- `Applications.ApiKey` and `Applications` API key functions mirroring
  the `StreamServers` key API (key_or_id acceptance, `stale_error_field:
  :lock_version`).
- `ApiKeysLive` mirroring `StreamServerApiKeysLive` page structure.

**Non-Goals:**

- No event-store emission for API key mutations (application API keys
  have none today; stream server keys have none either — the aggregate
  events stay on the application/stream server level).
- No key deletion — revocation is disable; a deletion flow can be a
  later change if needed.
- No secret-verification endpoint consuming `prefix` — lookup by
  presented secret prefix is groundwork for a separate change.
- No rename of `Applications.ApiKey` module or its context namespace;
  only the table is renamed.

## Decisions

### Table rename + column adds in one migration

The portal repo is SQLite. One new migration:

1. `drop` the unique indexes on `(:api_keys, [:application_id, :name])`
   and `(:api_keys, [:application_id, :hashed_api_key])` — dropping the
   name index removes name uniqueness; dropping the hash index lets it
   be recreated under a name matching the new table.
2. `rename table(:api_keys, to: table(:application_api_keys))`.
3. `alter table(:application_api_keys)`: add `prefix :string, null:
   false, default: ""` and `lock_version :integer, null: false,
   default: 1`. SQLite's `ADD COLUMN` needs a non-null default for
   `NOT NULL` on a non-empty table; the `""` default is inert because
   `create_api_key/1` always writes a real prefix (a second `""` row
   would collide on the unique index and fail loudly anyway).
4. Backfill each existing row's `prefix` with
   `ApiKeySecret.prefix("aak", Ecto.UUID.generate())`. Old secrets embed
   a different `aak_<id>` that cannot be recovered from the bcrypt hash;
   a fresh unique prefix is stored instead. Nothing consumes `prefix`
   yet, so no caller breaks. This needs `up/0`/`down/0` (repo calls in
   `up`), not `change/0`.
5. `create unique_index(:application_api_keys, [:prefix])` and
   `create unique_index(:application_api_keys, [:application_id,
   :hashed_api_key])` — names then follow the
   `application_api_keys_*` convention `unique_constraint` infers.

Alternative considered: rebuild the table (create new + copy + drop)
for a clean `NOT NULL` with no `""` default — rejected as heavier for
a dev-seeded table; the default is harmless. Alternative: keep old
index names and pass `name:` to `unique_constraint` — rejected so the
schema stays free of legacy-name references.

### Schema mirrors `StreamServers.ApiKey`

`schema "application_api_keys"`; add `prefix` and `lock_version`
fields; `changeset/2` drops `unsafe_validate_unique`/`unique_constraint`
on name (duplicates now allowed), keeps `unique_constraint` on
`(application_id, hashed_api_key)` (index now
`application_api_keys_application_id_hashed_api_key_index`) and adds
`unique_constraint(:prefix)`; gains `name_changeset/2`,
`description_changeset/2`, `enabled_changeset/2` each with
`optimistic_lock(:lock_version)`. `Application.has_many :api_keys` is
unchanged — it binds to the schema, not the table name.

### Context API mirrors `StreamServers`

- `list_api_keys(application_id)` — id instead of `%Application{}`,
  matching `list_stream_server_api_keys/1`.
- `get_api_key!/1`, `change_api_key/2` unchanged.
- `create_api_key/1` generates `prefix_id`, stores
  `ApiKeySecret.prefix("aak", prefix_id)` in `prefix` and the hash —
  the same `put_change` pair `create_stream_server_api_key/1` uses.
- New `rename_api_key/2`, `edit_api_key_description/2`,
  `enable_api_key/1`, `disable_api_key/1` accepting key or id via a
  `fetch_api_key/1` private helper, updates with
  `Repo.update(stale_error_field: :lock_version)`.
- Removed: `update_api_key/2`, `delete_api_key/1`,
  `list_applications_with_api_keys/0` (grouped page is gone).
  `generate_api_key_secret/1` stays as the `"aak"` delegate.
- `list_applications/0` gains a `:search` option (case-insensitive
  `like` on name) so the filter dropdown can narrow options the way
  `list_stream_servers(search:)` does.

### Page mirrors `StreamServerApiKeysLive`

Index-only: delete the `/api-keys/new` and `/api-keys/:id/edit` routes
and their `/stream-server-admin`-prefixed mirrors; `ApiKeysLive` keeps
only `:index`. The page copies the stream server keys page's structure:

- Required searchable `DropdownComponent` filter over applications
  (options `{application.name, application.id}`, no `empty_label`);
  pick → `push_patch` to `?application_id=`; unpicked →
  select-an-application prompt, no table, no add action.
- Event-driven add modal (same private `modal/1` component): read-only
  application name, name/description/enabled inputs,
  `application_id` injected from the filter assign on save.
- One-time secret banner (existing markup moves verbatim).
- Table: name + pencil → rename modal; API KEY column showing `prefix`
  with copy button; description (truncate/expand at 50 chars) + pencil →
  description modal; enabled checkbox → enable/disable. No Remove
  button, no whole-row edit. `lock_version` failures surface via the
  same `lock_version_error/1` form-error display.
- Sidebar unchanged — the "API keys" item under "Applications" already
  points here.

## Risks / Trade-offs

- **[`""` default on `prefix`]** → inert because creation always sets a
  prefix; a regression inserting `""` fails on the unique index.
- **[Existing secrets' embedded prefixes are orphaned]** — stored
  `prefix` won't match the `aak_<id>` inside pre-change secrets →
  acceptable: no prefix-lookup consumer exists yet, and the seeded key
  is dev-only; document in the release note if a real deploy exists.
- **[Removing delete accumulates disabled keys]** → intentional,
  matching stream server keys; a cleanup change can add deletion later.
- **[Non-unique names make keys harder to tell apart]** → description
  and `prefix` columns disambiguate; matches the stream server key
  decision.
- **[Deep links to `/new` and `/:id/edit` break]** → low risk; these
  were portal-internal routes removed in the same release.

## Migration Plan

Standard portal-repo migration (`dotenv -e .env mix ecto.migrate`).
Rollback (`mix ecto.rollback`) recreates `api_keys` without
`prefix`/`lock_version`; prefixes generated in the window are
irrelevant because the column is dropped. Deploy is atomic per repo —
no code path needs the old and new table at once once code and
migration ship together.
