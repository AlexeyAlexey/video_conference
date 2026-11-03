# Tasks

## 1. Schema and context

- [x] 1.1 Add per-field changesets to `StreamServerPublicKey` — `name_changeset/2`, `description_changeset/2`, `application_changeset/2` (requires `application_id`, keeps `assoc_constraint`), `enabled_changeset/2` — none casting `:key`; verify `ApplicationsTest` still compiles (`mix test test/video_conference/stream_server_admin_portal/applications_test.exs`)
- [x] 1.2 Add `rename_stream_server_public_key/2`, `edit_stream_server_public_key_description/2`, `switch_stream_server_public_key_application/2`, `enable_stream_server_public_key/1`, `disable_stream_server_public_key/1` to `Applications`, each fetching via `get_stream_server_public_key!/1` and updating through its dedicated changeset; add tests covering each function plus "update cannot change `key`" — verify the new tests pass
- [x] 1.3 Remove `update_stream_server_public_key/2` from `Applications` and replace its test block with the granular-function tests; verify `applications_test.exs` passes

## 2. LiveView rework

- [x] 2.1 Remove the `:edit` `apply_action` clause and `save_key(socket, :edit, _)`; add `modal`/`modal_key` assigns and open/close events; verify the LV compiles
- [x] 2.2 Update the table: add Public key column (show icon), pencils next to name and description, rename Status → Enabled with a real checkbox (`toggle-enabled` event carrying `phx-value-enabled` — the displayed state — to pick enable/disable), and `⋯` menu (daisyUI `details.dropdown`) containing "Change app" and "Remove"; verify existing list tests updated to the new markup pass
- [x] 2.3 Add the four event-driven modals: show-key (full key + copy button), rename form, description form, change-app (with a searchable `DropdownComponent` on a `to_form` map + `{:change_app_picked, id}` handler); wire save events to the granular context functions and refresh `assign_applications/1`; verify in `iex -S mix phx.server` or via tests
- [x] 2.4 Remove `/applications/stream-server-public-keys/:id/edit` from `router.ex` — both the real and `/stream-server-admin`-prefixed mirror route; verify no link/patch still targets it

## 3. Tests and verification

- [x] 3.1 Rework `stream_server_public_keys_live_test.exs`: drop edit-form tests, add coverage for show-key modal (+copy control), rename modal, description modal, change-app modal + dropdown, enabled checkbox toggle, and `⋯` menu (Change app / Remove items); verify the file passes with `dotenv -e .env.test mix test`
- [x] 3.2 Verify responsiveness: exercise the page at mobile, tablet, and desktop widths — tables scroll inside their container, modals and the `⋯` menu stay inside the viewport — using the integrated browser (`dotenv -e .env mix phx.server` + browser preview); confirm no horizontal overflow or clipped menu
- [x] 3.3 Validate the full flow in the integrated browser: open the show-key modal and copy, rename a key, edit a description, toggle the enabled checkbox, change a key's application via the `⋯` menu, and remove a key; confirm each persists after reload
- [x] 3.4 Run `dotenv -e .env.test mix precommit` and fix any warnings/failures
