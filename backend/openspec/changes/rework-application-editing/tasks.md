# Tasks

## 1. Schema, migration, and context

- [x] 1.1 Add a migration creating a `lock_version` integer column (default 1, not null) on `applications` in `priv/stream_server_admin_portal_repo/migrations/`; verify `mix ecto.migrate` succeeds
- [x] 1.2 Add `field :lock_version, :integer, default: 1` to the `Application` schema; add per-field changesets — `name_changeset/2` (keeps required + unique-name validations), `description_changeset/2`, `enabled_changeset/2` (requires `enabled`) — each piping `optimistic_lock(:lock_version)`; leave `changeset/2` (create path) unchanged; verify `applications_test.exs` still compiles
- [x] 1.3 Add `rename_application/2`, `edit_application_description/2`, `enable_application/1`, and `disable_application/1` to `Applications`, each fetching with `get_application!/1` and calling `Repo.update(stale_error_field: :lock_version)`; route `delete_application/1` through `Ecto.Changeset.change/1 |> optimistic_lock(:lock_version) |> Repo.delete(stale_error_field: :lock_version)`; add tests covering each function plus "update increments `lock_version`" and "stale update/delete fails with a changeset error" — verify the new tests pass
- [x] 1.4 Remove `update_application/2` from `Applications` and switch its test call sites to the granular functions; verify `applications_test.exs` passes

## 2. LiveView rework

- [x] 2.1 Remove the `:edit` `apply_action` clause and `save_application(socket, :edit, _)`; add `modal`/`modal_application`/`modal_form` assigns, open/close events, and the private `modal` function component copied from `StreamServersLive`; verify the LiveView compiles
- [x] 2.2 Update the table: add pencils opening modals on the Name and Description cells (keeping the existing `description_long?`/`truncated_description` expand markup), replace the "Yes"/"No" Enabled cell with a real checkbox (`phx-click="toggle-enabled"` + `phx-value-id` + `phx-value-enabled` carrying the displayed state), and keep Remove as an inline `data-confirm` button; verify existing list tests updated to the new markup pass
- [x] 2.3 Add the two event-driven modals — rename (changeset-backed form so duplicate names error inline) and description (`to_form` map + textarea) — wired to `rename_application/2` and `edit_application_description/2` with modal-close + `@applications` refetch on success; verify via tests or `mix phx.server`
- [x] 2.4 Remove `/applications/:id/edit` from `router.ex` — both the real and `/stream-server-admin`-prefixed mirror route; verify no link/patch still targets it

## 3. Tests and verification

- [x] 3.1 Rework `applications_live_test.exs`: drop edit-form tests; add coverage for the rename modal (incl. duplicate-name error), the description modal, the immediate enabled checkbox toggle, and that no edit link/route remains; verify the file passes with `dotenv -e .env.test mix test`
- [ ] 3.2 Verify responsiveness: exercise the page at mobile, tablet, and desktop widths — the table scrolls inside its container and modals stay inside the viewport — using the integrated browser (`dotenv -e .env mix phx.server` + browser preview); confirm no horizontal overflow
- [ ] 3.3 Validate the full flow in the integrated browser: rename an application (incl. a duplicate name rejection), edit a description, toggle enabled off and on, and remove an application; confirm each persists after reload
- [x] 3.4 Run `dotenv -e .env.test mix precommit` and fix any warnings/failures
