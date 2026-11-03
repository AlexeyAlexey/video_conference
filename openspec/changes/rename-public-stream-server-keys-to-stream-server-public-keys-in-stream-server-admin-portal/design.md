# Design

## Context

The stream server admin portal feature from the archived
`add-public-stream-server-keys` change is being renamed to
`stream_server_public_keys` terminology (see proposal.md). Everything
that must move lives in the portal slice: the portal-repo migration,
`StreamServerAdminPortal.Applications` (schema + context),
`StreamServerAdminPortal.PublicStreamServerKeysLive`, the portal router,
the portal sidebar, and the matching fixtures/tests. The `/admin`
portal keeps `public_stream_server_keys` — identical names exist in both
portals after this change and are intentionally unrelated.

Per the user's decisions: the rename covers the **entire user-facing
surface** (URL, labels, headers) — not just internals — and the portal
migration is **edited in place** rather than a new rename migration,
because the table was created by the same unreleased change and dev data
is disposable.

## Goals / Non-Goals

**Goals:**

- One consistent `stream_server_public_keys` / `key` vocabulary across
  schema, context, LiveView, routes, DOM ids, fixtures, tests, and UI
  text.
- The dev/test portal databases end up with `stream_server_public_keys`
  after a normal `ecto.setup`/`mix test` — no manual rename migration.
- Zero behavior change besides naming: identical list/filter/CRUD/copy/
  truncation semantics.

**Non-Goals:**

- Renaming the `/admin` portal's `public_stream_server_keys` (it keeps
  its name — the two portals' similar naming is accepted).
- Renaming the spec capability `portal-public-stream-server-keys` (a
  capability path is a durable identifier; only requirement names and
  texts adopt the new terminology).
- Preserving data in already-migrated dev portal databases.
- Any functional change.

## Decisions

### D1: Naming map

| Old | New |
| --- | --- |
| table `public_stream_server_keys` | `stream_server_public_keys` |
| field `public_key` | `key` |
| field `disabled` (default false) | `enabled` (default true) |
| schema `Applications.PublicStreamServerKey` | `Applications.StreamServerPublicKey` |
| `has_many :public_stream_server_keys` | `has_many :stream_server_public_keys` |
| context `*_public_stream_server_key*` fns | `*_stream_server_public_key*` fns |
| `list_applications_with_public_keys/1` | `list_applications_with_stream_server_public_keys/1` |
| `PublicStreamServerKeysLive` | `StreamServerPublicKeysLive` |
| routes `/applications/public-stream-server-keys*` | `/applications/stream-server-public-keys*` |
| form param `public_stream_server_key` | `stream_server_public_key` |
| DOM ids `public-key-*`, `public-keys-*` | `key-*`, `keys-*` (e.g. `key-row-`, `key-form`, `copy-key-id-`, `no-keys-`) |
| sidebar `sidebar-public-keys-link` | `sidebar-stream-server-public-keys-link` |
| UI text "Public keys"/"Public Keys" | "Stream server public keys"/"Stream Server Public Keys" |
| column "Public key Id" | "Key Id" |
| fixture `public_stream_server_key_fixture` | `stream_server_public_key_fixture` |
| test `PublicStreamServerKeysLiveTest` | `StreamServerPublicKeysLiveTest` |

`valid_public_key_pem` keeps its name — it describes PEM content, not
the entity. `application_picked`/`filter_picked`, `application-filter-*`
ids, and `no-applications` are application-side and unchanged.

### D2: Edit the create migration in place

`20261103100000_create_public_stream_server_keys.exs` is renamed to
`20261103100000_create_stream_server_public_keys.exs` (Ecto tracks the
version prefix, so renaming the file is safe) with module
`CreateStreamServerPublicKeys`, creating `stream_server_public_keys`
with a `key` column directly. Alternative — a second `rename` migration —
rejected: it keeps dead naming in history forever and still forces a
re-migrate on every existing DB. The in-place edit is only safe because
the migration is unreleased; databases that already ran it keep an
`public_stream_server_keys` table and a recorded version that will never
re-run — they must drop the table and delete the version row, or
recreate the portal database (dev/test only; documented in tasks).

### D3: Full-surface rename, including URL

Routes move to `/applications/stream-server-public-keys*` with matching
`/stream-server-admin`-prefixed mirror routes; labels follow ("Stream
server public keys" in the sidebar, "Stream Server Public Keys" title,
"Key Id" column). A half-renamed surface would leave the portal's own
vocabulary inconsistent — the user's explicit choice.

### D4: Delta expresses renames via RENAMED + MODIFIED

The `portal-public-stream-server-keys` delta declares all five
requirement renames under `## RENAMED Requirements` and carries the
updated blocks under `## MODIFIED Requirements` (matched by their
existing names), so the merge both renames and rewrites text. The
capability directory itself is NOT renamed — see Non-Goals.

## Risks / Trade-offs

- [Already-migrated dev portal DBs keep the old table] → Mitigated: tasks
  document recreating the portal DB (or dropping the table + version
  row); only dev/test DBs exist today.
- [A same-named table in the main repo (`/admin` feature) and now a
  differently-named one in the portal repo may confuse future readers] →
  Accepted: the two registries are intentionally distinct; names now
  match each portal's own terminology.
- [Renamed DOM ids break any external selectors/scripts] → Accepted: ids
  are internal test/UI hooks; tests updated in the same change.

## Migration Plan

1. Rewrite the portal migration file in place (new file name, module,
   table, `key` column — same version timestamp).
2. Dev/test: recreate the portal DB (`mix ecto.drop -r
   VideoConference.StreamServerAdminPortal.Repo` + `ecto.setup`, or drop
   the stale table and its `schema_migrations` row). No data is
   preserved.
