# Design

## Context

`StreamServerPublicKeysLive` currently lists applications with their keys
grouped under each (`list_applications_with_stream_server_public_keys/1`),
treats the application filter as optional (`empty_label="All applications"`),
and adds keys through a separate `:new` live_action route rendering an inline
card form with its own application dropdown. `ApiKeysLive` (and the newer
`StreamServerApiKeysLive`) already implement the target pattern: resolve the
`application_id` query param to a struct, require a selection before listing,
flat key table, `:add` modal with the owner injected. See proposal.md — Why.

## Goals / Non-Goals

**Goals:**

- One interaction pattern across all portal key-management pages: select an
  owner, then manage a flat list.
- Drop the `:new` route and the grouped preload in favor of a modal add flow
  and a flat `list_stream_server_public_keys/1` query.
- Keep every public-key-specific feature: key id copy, show-key modal,
  rename/description modals, enabled toggle, Change app, Remove.

**Non-Goals:**

- No changes to the `StreamServerPublicKey` schema, changesets, or event
  emission — all mutations keep their current event-store behavior.
- No changes to `DropdownComponent`, the sidebar, or page URL/param names.
- No search/filter inside the key list itself.

## Decisions

### Mirror `ApiKeysLive` structure exactly

`handle_params/3` does `Enum.find(list_applications(), &(&1.id ==
params["application_id"]))` and assigns `@application` (struct or `nil`),
`@filter_form`, and `@public_keys` (`[]` when `nil`). Render shows the
prompt `#select-application-prompt` when `@application == nil`, otherwise
`#public-keys-section` with a single `#public-keys-table`. The Add button
carries `:if={@application}` so it can never be clicked without a selection.

*Alternative:* keep grouped preload and just hide other groups — rejected;
it keeps the extra query and a dead "all applications" state the new spec
removes.

### New flat context query, drop the grouped one

`Applications.list_stream_server_public_keys(application_id)` orders by name
and mirrors `list_api_keys/1`. `list_applications_with_stream_server_public_keys/1`
is deleted — this page was its only production caller and its docstring says
it exists for the grouped listing. Its context tests are replaced with flat
-list tests.

*Alternative:* keep the grouped function — rejected; dead public API with a
maintenance cost, and the events it preloads are no longer needed.

### `:add` modal replaces the `:new` route

`open-add-modal` assigns `modal: :add` and a fresh changeset
(`%StreamServerPublicKey{enabled: true}`); the modal shows the selected
application's name as text (`#add-key-application`) and `save` merges
`"application_id" => socket.assigns.application.id` before calling
`create_stream_server_public_key/1`. Both `/new` routes are removed from the
portal router (stripped path and the `/stream-server-admin` mirror route).
`apply_action/2`, `live_action`, `filter_query/1`, and the
`{:application_picked, _}` handler die with the card form.

*Alternative:* keep the route for deep-linking — rejected; no other portal
page deep-links an add form, and the modal keeps the selected application in
view.

### Search-backed dropdown options

The selection control uses `options={&application_options/1}` (search-backed,
like `ApiKeysLive`) instead of the preloaded `@filter_applications` list.
`@filter_applications` is kept only if the change-app modal still needs a
full list — it does, since its dropdown is not search-backed today; making it
search-backed too keeps one options source and drops the assign entirely.

### Row-level assigns stay struct-based

`open_modal/3` already loads `%StreamServerPublicKey{}` via
`get_stream_server_public_key!/1`, so rename/description/change-app/remove
keep working unchanged against `modal_key`. `toggle-enabled` mirrors
`ApiKeysLive`: find the loaded key in `@public_keys` (fall back to id) so the
write uses a fresh `lock_version`. After `save-application` (Change app),
`assign_public_keys/1` reloads the list and the moved key naturally
disappears — no special handling needed.

## Risks / Trade-offs

- Removed route breaks bookmarks to `.../new` → low; the page still loads
  `:index` for unknown live_actions only if routed — the route is deleted, so
  Phoenix 404s, which is acceptable for an admin portal.
- `Enum.find` on `list_applications()` per `handle_params` is O(n) with an
  extra query — same cost `ApiKeysLive` already pays; application counts are
  small.
- Deleting a context function removes a tested public API → mitigated by
  replacing its tests in the same change; no other callers exist.
