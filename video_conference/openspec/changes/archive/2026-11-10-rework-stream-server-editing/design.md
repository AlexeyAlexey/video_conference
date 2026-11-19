# Design

## Context

`StreamServersLive` (stream server admin portal) edits every attribute
through patch-driven `:new`/`:edit` live actions sharing one
`StreamServer.changeset/2`, which casts `:host` — so any update can
rewrite a server's network identity, and nothing stops two servers
sharing a `host`. The `:assign` action renders a `<form>` of
per-application checkboxes saved in bulk through
`assign_applications/2` (`put_assoc` replace-all). The public keys page
was already reworked the same way this change proposes: per-field
changesets, granular context functions, event-driven modals via a
private `modal` function component, and a `phx-click` checkbox that
carries the displayed state. The portal router keeps
`/stream-server-admin`-prefixed mirror routes for LiveView
`route_info` resolution, so every route-based UI state costs two route
lines. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**

- Make `host` impossible to change after creation, at the changeset
  level, and unique across servers, at the database level.
- Replace whole-row edit with event-driven per-field modals — no new
  routes.
- Make each assign-view checkbox toggle persist immediately.
- Add a Description column so the field stays editable after the
  `:edit` form is gone.

**Non-Goals:**

- No event store integration — stream server mutations emit no events.
- No reusable `<.modal>` in core_components — copy the private `modal`
  component pattern from `StreamServerPublicKeysLive` into this
  LiveView.
- `host` stays optional (unique-when-present); not making it required.
- No inline cell editing — every field edit is a modal.

## Decisions

### 1. `host` immutability + uniqueness via per-field changesets

There is no shared update changeset — each update path gets a dedicated
changeset on the schema that casts only its own field:

- `changeset/2` (create path): keeps casting
  `[:name, :description, :host, :country, :settings, :cert_hash]`,
  keeps `validate_required([:name])`, and gains
  `unsafe_validate_unique(:host, Repo)` +
  `unique_constraint(:host)`.
- `name_changeset/2`: casts `[:name]` only, keeps the required +
  unique-name validations.
- `description_changeset/2`: casts `[:description]` only.
- `country_changeset/2`: casts `[:country]` only, keeps the
  `Countries` inclusion validation.
- `cert_hash_changeset/2`: casts `[:cert_hash]` only.

`host` never appears in any update cast, so immutability is
structural — a stray `host` param is un-castable rather than silently
rewriting the server identity. A migration adds
`unique_index(:stream_servers, [:host])` and a `lock_version` integer
column (default 1, not null); SQLite permits multiple NULLs, so unset
hosts don't collide. The row simply has no host pencil — display stays
plain text.

### 2. Granular context functions; generic update and bulk assign removed

```
rename_stream_server(id, name)              -> name_changeset
edit_stream_server_description(id, desc)    -> description_changeset
edit_stream_server_country(id, country)     -> country_changeset
edit_stream_server_cert_hash(id, hash)      -> cert_hash_changeset
assign_application(stream_server_id, application_id)
unassign_application(stream_server_id, application_id)
```

Each field function fetches with `get_stream_server!/1` and returns
`{:ok, server} | {:error, changeset}`. Every update changeset pipes
`optimistic_lock(:lock_version)` and every `Repo.update` passes
`stale_error_field: :lock_version`, so a stale edit fails with a
changeset error instead of `Ecto.StaleEntryError` — identical to the
public keys treatment. `delete_stream_server/1` goes through
`Ecto.Changeset.change/1 |> optimistic_lock(:lock_version) |>
Repo.delete(stale_error_field: :lock_version)` for the same reason.

`assign_application/2` inserts an `ApplicationStreamServer` row
(`on_conflict: :nothing` — a repeated toggle is idempotent);
`unassign_application/2` deletes the matching join row. Both return
`{:ok, stream_server}` reloaded with `:applications` preloaded, so the
caller always sees the post-change state. Neither goes through
`lock_version` — they write join rows, not the server record, and the
pair is already idempotent.

`update_stream_server/2` is **deleted**: its only caller is the `:edit`
form being removed, and keeping a broad update path invites future
callers to re-add `host` to a cast. `assign_applications/2` is also
**deleted**: its only production caller is `save_assign`, and the
replace-all semantics no longer match the per-toggle UI — test call
sites switch to `assign_application/2`.

### 3. Event-driven modals on `:index`, not new live actions

The LiveView gains `modal` (`nil | :rename | :edit_description |
:edit_country | :edit_cert_hash`), `modal_server`, and `modal_form`
assigns plus open/close `phx-click` events — the same mechanics as
`StreamServerPublicKeysLive`, including copying its private `modal`
function component (daisyUI `modal modal-open` overlay + `modal-box`
panel + backdrop close). The alternative (route-driven modals) costs
four live actions × two router lines (mirror routes) for pure UI
chrome.

The `:edit` live action, its `apply_action` clause,
`save_stream_server(socket, :edit, _)`, and both `/:id/edit` router
lines (real + mirror) are deleted.

### 4. Modal form mechanics

- **Rename**: changeset-backed form (`name_changeset` on the target
  server) so a duplicate name renders "has already been taken" inline
  in the modal — unlike public keys, `name` here carries validations.
- **Description**: `to_form(%{"description" => server.description})`
  map form with a textarea; no validations, so a changeset is
  unnecessary.
- **Country**: `to_form(%{"country" => server.country},
  as: :edit_country)` feeding the `DropdownComponent` (which requires a
  `Phoenix.HTML.FormField`), `on_change` → `{:country_picked, code}`
  handled in `handle_info`, searchable with `empty_label="None"`.
- **Cert hash**: `to_form(%{"cert_hash" => server.cert_hash})` map
  form; saving a blank value clears the column.

Each save event calls its granular context function; on `{:ok, _}` the
modal closes and `@stream_servers` is refetched (same
`list_stream_servers(application_id: filter)` call `handle_params`
uses); on error the modal stays open with `modal_form` re-assigned from
the failed changeset, or a flash for non-changeset failures.

### 5. Table changes

- New **Description** column reusing the public-keys pattern:
  `description_long?`/`truncated_description` helpers (>50 chars →
  short/full `JS.toggle_class` expand) with an in-cell pencil.
- **Name**, **Country**, and **Cert hash** cells gain pencils. The cert
  hash cell keeps its "Set" + hidden value + copy-button markup; the
  pencil sits beside it. **Host** gets no affordance.
- Row actions stay two visible controls — **Assign** (unchanged patch
  link to `:assign`) and **Remove** (unchanged `data-confirm` delete).
  A `⋯` menu like public keys was considered and rejected: those menu
  items open modals, whereas Assign is a real navigation target
  deserving a link.

### 6. Assign view: same route, immediate toggles

The `/stream-servers/:id/assign` live action stays — the spec's
"dedicated assign view" language fits a route, and it keeps
deep-linking. The `<form>` and Save button are removed; each
`<label>`'s checkbox gets `phx-click="toggle-assignment"` +
`phx-value-application-id` + `phx-value-assigned` (the *displayed*
state, mirroring `phx-value-enabled` on public keys). The handler picks
`unassign_application` when the UI shows assigned and
`assign_application` when it shows unassigned, then re-assigns
`assigned_application_ids` from the returned server — no refetch. On
failure, flash an error and leave the list as rendered (LiveView
restores the checkbox state from assigns on the next render). Cancel
becomes a "Back" link to `index_path(application_filter)`; the
`save_assign` handler and the hidden `application_ids[]` input are
deleted.

## Risks / Trade-offs

- [Existing databases may already contain duplicate `host` values, so
  the unique-index migration can fail] → dev/seed data is clean, but
  the migration should be checked against real data before deploy; if
  duplicates exist they must be resolved manually first.
- [An admin who mistypes `host` at creation cannot fix it — delete and
  recreate is the only repair] → accepted consequence of immutability;
  the host is the server's identity.
- [Rapid double-toggles or two admins toggling the same pair race on
  the unique join index] → `on_conflict: :nothing` makes assign
  idempotent; unassign is `delete_all` on the pair, also idempotent.
- [A stale-edit error lands on `:lock_version`, which no modal field
  renders] → same limitation as public keys; the modal re-opens with
  the changeset and the admin can re-trigger the edit, which reloads
  the record. A visible "record changed" flash can be added later if
  it proves confusing.
- [Description column widens the table on narrow viewports] → reuse
  the `max-w-64 break-all` + truncation markup from public keys;
  verify at mobile/tablet/desktop in the browser check.
- [Tests asserting the edit form, `save_assign`, and
  `assign_applications/2` will break] → expected; both test files are
  reworked as part of the change.
