# Design

## Context

`StreamServerPublicKeysLive` currently edits every attribute through one
patch-driven form (`:new`/`:edit` live actions). The shared
`StreamServerPublicKey.changeset/2` casts `:key`, so any update can rewrite
the public key material. The codebase has no modal component and no
action-menu pattern — this change introduces the first of both. The portal
router keeps `/stream-server-admin`-prefixed mirror routes for LiveView
`route_info` resolution, so every route-based UI state costs two route
lines. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**
- Make `key` impossible to change after creation, at the changeset level.
- Replace whole-row edit with event-driven per-field modals — no new routes.
- Add the `⋯` row menu (Change app, Remove), Enabled checkbox, and
  Public key show-modal without leaving the `:index` action.

**Non-Goals:**
- No reusable `<.modal>` component in core_components — the markup lives
  in this LiveView; extraction can happen when a second consumer appears.
- No changes to the `:new` form beyond what immutability implies (it still
  collects `key`, which stays required).
- No database migration — `key` stays a plain column; immutability is
  enforced in the update changeset.

## Decisions

### 1. Immutability via per-field changesets

There is no shared update changeset — each update path gets a dedicated
changeset on the schema that casts only its own field:

- `changeset/2` (create path — unchanged): casts
  `[:name, :key, :enabled, :description, :application_id]`, requires
  `[:key, :application_id]`.
- `name_changeset/2`: casts `[:name]` only.
- `description_changeset/2`: casts `[:description]` only.
- `application_changeset/2`: casts `[:application_id]` only, requires it,
  keeps `assoc_constraint(:application)`.
- `enabled_changeset/2`: casts `[:enabled]` only, requires it.

`key` never appears in any update cast, so immutability is structural —
a stray `key` param is un-castable rather than silently updating the
material. A single shared `update_changeset/2` was considered and
rejected: one cast would let a stray param for a *different* permitted
field slip into a targeted operation (a rename could also flip
`enabled`), and per-field changesets give each field a home for its own
future validations.

### 2. Five granular context functions, generic update removed

```
rename_stream_server_public_key(id, name)                  → name_changeset
edit_stream_server_public_key_description(id, description) → description_changeset
switch_stream_server_public_key_application(id, app_id)    → application_changeset
enable_stream_server_public_key(id)                        → enabled_changeset(enabled: true)
disable_stream_server_public_key(id)                       → enabled_changeset(enabled: false)
```

Each fetches with `get_stream_server_public_key!/1` (bang — matches the
context's existing getters), pipes through its dedicated changeset, and
returns `{:ok, key} | {:error, changeset}`. The generic
`update_stream_server_public_key/2` is **deleted**: its only caller is
the `:edit` form being removed, and keeping a broad update path invites
future callers to re-add `key` to a cast. `change_stream_server_public_key/2`
stays — the `:new` form needs it.

### 3. Event-driven modals on `:index`, not new live actions

The LiveView gains two assigns — `modal` (`nil | :show_key | :rename |
:edit_description | :change_app`) and `modal_key` (the target key struct) —
plus `phx-click` open/close events. The alternative was route-driven modals
(`:edit_name`, `:edit_description`, `:change_app`, `:show_key` actions);
that costs 4 × 2 = 8 router lines (mirror routes) and URL bookkeeping for
state that is purely UI chrome. Events keep everything on `:index`.

Modal markup lives directly in `render/1` as function components private
to the module — a daisyUI-style fixed overlay + `modal-box` panel. The
`:edit` live action, its `apply_action` clause, `save_key(socket, :edit, _)`,
and both `/​:id/edit` router lines (real + mirror) are deleted.

### 4. Form mechanics inside modals

- **Rename / Edit description**: small `to_form` maps
  (`%{"name" => key.name}` / `%{"description" => key.description}`), submitted
  to dedicated `save_name` / `save_description` events. Name and description
  carry no validations, so changesets aren't needed for these forms.
- **Change app**: the modal needs a `DropdownComponent`, which requires a
  `Phoenix.HTML.FormField` — build `to_form(%{"application_id" =>
  key.application_id}, as: :change_app)` like the existing filter form, with
  `on_change` → `{:change_app_picked, id}` handled in `handle_info`. A Save
  button calls `switch_stream_server_public_key_application/2`.
- **Show key**: no form — `<code>` block with the full `key` plus a copy
  button reusing the existing `navigator.clipboard.writeText` + hidden-span
  pattern from the Key Id column.

### 5. Enabled checkbox toggles immediately

`phx-click="toggle-enabled"` + `phx-value-id` + `phx-value-enabled` on a
real `<input type="checkbox">` (checked when `key.enabled`).
`phx-value-enabled` carries the displayed state, so the handler picks
`disable_` when the UI shows enabled and `enable_` when it shows
disabled — no extra fetch. It then refreshes the grouped list via the
existing `assign_applications/1`. No confirmation — it's a
non-destructive flip; the checkbox itself shows the result.

### 6. `⋯` menu is a daisyUI dropdown, not DropdownComponent

`DropdownComponent` is form-bound (hidden input + `on_change` contract) —
wrong tool for an action menu. A `details.dropdown` (or `dropdown` +
`phx-click-away` alternative) opens a `<ul>` with "Change app" (opens the
modal) and "Remove" (existing `delete` event + `data-confirm`). Using
`details` gives free click-away-close semantics without JS hooks.

## Risks / Trade-offs

- [First modal markup is ad-hoc and LiveView-local] → Keeps scope small;
  if the pattern repeats (API keys page is the obvious next candidate),
  extract `<.modal>` to core_components then.
- [Event-driven modals aren't deep-linkable] → Accepted: these are
  micro-edits, not destinations. If deep-linking is ever wanted, promote
  to live actions later.
- [`details.dropdown` inside a horizontally scrolling table can clip the
  menu, and modals can overflow narrow viewports] → `dropdown-end` +
  `dropdown-top` positioning classes and a max-width modal panel; verify
  at mobile/tablet/desktop widths in the integrated browser (tasks 3.2).
- [Tests that assert on "Enabled"/"Disabled" text and the edit link will
  break] → Expected; the LV test file is reworked as part of the change.
