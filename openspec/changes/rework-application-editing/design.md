# Design

## Context

`ApplicationsLive` (stream server admin portal) edits every attribute
through patch-driven `:new`/`:edit` live actions sharing one
`Application.changeset/2`, which casts `[:name, :description,
:enabled]` — so a rename form submit can also silently flip `enabled`,
and nothing guards two admins editing the same application
concurrently. The `applications` table has no `lock_version` column;
`stream_servers` and `stream_server_public_keys` already have one. The
portal router keeps `/stream-server-admin`-prefixed mirror routes for
LiveView `route_info` resolution, so every route-based UI state costs
two route lines. The public keys and stream servers pages were already
reworked the same way this change proposes: per-field changesets,
granular context functions, event-driven modals via a private `modal`
function component, and a `phx-click` enabled checkbox that carries
the displayed state. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**

- Replace whole-row edit with event-driven per-field modals — no new
  routes.
- Make the enabled flag a live checkbox that persists on click.
- Guard every application update/delete with `lock_version`
  optimistic concurrency, surfacing stale conflicts as changeset
  errors.

**Non-Goals:**

- No reusable `<.modal>` in core_components — copy the private `modal`
  component pattern from `StreamServerPublicKeysLive` into this
  LiveView.
- No event store integration — application mutations emit no events.
- No `lock_version` or editing rework on `api_keys` — the API keys
  page keeps its current full-row edit and is a candidate for a
  follow-up change.
- No inline cell editing — every field edit is a modal.
- No `⋯` row menu — Remove stays a plain inline button, matching the
  stream servers page.

## Decisions

### 1. Per-field changesets, all lock-versioned

There is no shared update changeset — each update path gets a
dedicated changeset on the schema that casts only its own field:

- `changeset/2` (create path — unchanged): casts
  `[:name, :description, :enabled]`, keeps
  `validate_required([:name])` + `unsafe_validate_unique(:name, Repo)`
  + `unique_constraint(:name)`.
- `name_changeset/2`: casts `[:name]` only, keeps the required +
  unique-name validations.
- `description_changeset/2`: casts `[:description]` only.
- `enabled_changeset/2`: casts `[:enabled]` only, requires it.

Each update changeset pipes `optimistic_lock(:lock_version)`; the
schema gains `field :lock_version, :integer, default: 1`. A migration
adds `lock_version` (integer, default 1, not null) to `applications`
in `priv/stream_server_admin_portal_repo/migrations/` — identical to
the stream servers and public keys migrations. The rename changeset is
changeset-backed rather than a plain map because `name` carries
required + uniqueness validations (unlike public keys' free-form name,
like stream servers').

### 2. Granular context functions; generic update removed

```
rename_application(id, name)                  -> name_changeset
edit_application_description(id, description) -> description_changeset
enable_application(id)                        -> enabled_changeset(true)
disable_application(id)                       -> enabled_changeset(false)
```

Each fetches with `get_application!/1`, pipes through its dedicated
changeset, and calls `Repo.update(stale_error_field: :lock_version)`
returning `{:ok, application} | {:error, changeset}` — identical to
the public keys treatment. `delete_application/1` keeps its
struct-taking signature but goes through
`Ecto.Changeset.change/1 |> optimistic_lock(:lock_version) |>
Repo.delete(stale_error_field: :lock_version)` for the same reason.

`update_application/2` is **deleted**: its only production caller is
the `:edit` form being removed, and keeping a broad update path
invites future callers to write fields outside a targeted operation.
`change_application/2` stays — the `:new` form needs it.

### 3. Event-driven modals on `:index`, not new live actions

The LiveView gains `modal` (`nil | :rename | :edit_description`),
`modal_application`, and `modal_form` assigns plus open/close
`phx-click` events — the same mechanics as `StreamServersLive`,
including copying its private `modal` function component (daisyUI
`modal modal-open` overlay + `modal-box` panel + backdrop close). The
alternative (route-driven modals) costs two live actions × two router
lines (mirror routes) for pure UI chrome.

The `:edit` live action, its `apply_action` clause,
`save_application(socket, :edit, _)`, and both `/:id/edit` router
lines (real + mirror) are deleted. The `:new` form is unchanged — it
still collects name, description, and enabled.

### 4. Modal form mechanics

- **Rename**: changeset-backed form (`name_changeset` on the target
  application) so a duplicate name renders "has already been taken"
  inline in the modal — the stream servers rename pattern, since
  `name` carries validations here.
- **Description**: `to_form(%{"description" => app.description})` map
  form with a textarea; no validations, so a changeset is
  unnecessary.

Each save event calls its granular context function; on `{:ok, _}` the
modal closes and `@applications` is refetched
(`Applications.list_applications()`); on error the modal stays open
with `modal_form` re-assigned from the failed changeset.

### 5. Enabled checkbox toggles immediately

`phx-click="toggle-enabled"` + `phx-value-id` +
`phx-value-enabled` on a real `<input type="checkbox">` (checked when
`application.enabled`), replacing the "Yes"/"No" text cell.
`phx-value-enabled` carries the displayed state, so the handler picks
`disable_application` when the UI shows enabled and
`enable_application` when it shows disabled — the public keys
pattern. On `{:ok, _}` the applications list is refetched; on error a
flash reports the flag cannot be changed and the next render restores
the checkbox from assigns. No confirmation — it's a non-destructive
flip; the checkbox itself shows the result.

### 6. Table changes

- **Name** and **Description** cells gain pencil buttons opening their
  modals; the description cell keeps its existing
  `description_long?`/`truncated_description` (>50 chars →
  short/full `JS.toggle_class` expand) markup, with the pencil beside
  it as on the public keys page.
- Row actions keep only **Remove** (unchanged `data-confirm` delete) —
  no `⋯` menu, matching stream servers' choice when the remaining
  actions don't open modals.

## Risks / Trade-offs

- [Removing `/applications/:id/edit` breaks bookmarked or shared links
  to the edit form] → Accepted BREAKING change, same as both reference
  pages; the route list shrinks rather than redirects.
- [A stale-edit error lands on `:lock_version`, which no modal field
  renders] → Same accepted limitation as public keys and stream
  servers; the modal re-opens with the changeset and the admin can
  re-trigger the edit, which reloads the record. A visible "record
  changed" flash can be added later if it proves confusing.
- [A stale `toggle-enabled` or delete fails with a changeset error
  carrying no obvious user message] → The handlers flash a generic
  error ("The enabled flag cannot be changed" / "The application
  cannot be removed") as on the public keys page.
- [Tests asserting the edit form, "Yes"/"No" text, and
  `update_application/2` will break] → Expected; both test files are
  reworked as part of the change.
- [Deleting an application cascades to API keys and public keys, whose
  own `lock_version`s are untouched] → Cascade is a DB-level FK
  `delete_all`; the guard applies to the application row itself, which
  is the record the admin holds — consistent with stream servers'
  join-row treatment.
