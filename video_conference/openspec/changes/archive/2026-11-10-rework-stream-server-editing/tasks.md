# Tasks

## 1. Schema, migration, and context

- [x] 1.1 Add a migration creating `unique_index(:stream_servers, [:host])` and a `lock_version` integer column (default 1, not null) on `stream_servers` in `priv/stream_server_admin_portal_repo/migrations/`; verify `mix ecto.migrate` succeeds on a database with no duplicate hosts
- [x] 1.2 Add `field :lock_version, :integer, default: 1` to the `StreamServer` schema; add per-field changesets — `name_changeset/2` (keeps required + unique-name validations), `description_changeset/2`, `country_changeset/2` (keeps `Countries` inclusion), `cert_hash_changeset/2` — each piping `optimistic_lock(:lock_version)` and none casting `:host`; extend `changeset/2` with `unsafe_validate_unique(:host, Repo)` + `unique_constraint(:host)`; verify `stream_servers_test.exs` still compiles
- [x] 1.3 Add `rename_stream_server/2`, `edit_stream_server_description/2`, `edit_stream_server_country/2`, `edit_stream_server_cert_hash/2`, `assign_application/2` (`on_conflict: :nothing` join insert), and `unassign_application/2` (join delete) to `StreamServers`, field updates via `Repo.update(stale_error_field: :lock_version)` returning `{:ok, server}` with `:applications` preloaded or `{:error, changeset}`; route `delete_stream_server/1` through `optimistic_lock` + `Repo.delete(stale_error_field: :lock_version)`; add tests covering each function plus "no update path can change `host`", "duplicate `host` rejected on create", "update increments `lock_version`", and "stale update/delete fails with a changeset error" — verify the new tests pass
- [x] 1.4 Remove `update_stream_server/2` and `assign_applications/2` from `StreamServers` and switch their test call sites to `assign_application/2`; verify `stream_servers_test.exs` passes

## 2. LiveView rework

- [x] 2.1 Remove the `:edit` `apply_action` clause and `save_stream_server(socket, :edit, _)`; add `modal`/`modal_server`/`modal_form` assigns, open/close events, and the private `modal` function component copied from `StreamServerPublicKeysLive`; verify the LiveView compiles
- [x] 2.2 Update the table: add a Description column with `description_long?`/`truncated_description` expand-toggle markup, pencils opening modals on the Name/Description/Country/Cert hash cells (no pencil on Host), and keep the cert hash "Set" + copy control beside its pencil; verify existing list tests updated to the new markup pass
- [x] 2.3 Add the four event-driven modals — rename (changeset-backed form so duplicate names error inline), description (`to_form` map + textarea), country (`to_form` map + searchable `DropdownComponent` + `{:country_picked, code}` handler + `empty_label="None"`), cert hash (`to_form` map, blank clears) — wired to the granular context functions with modal-close + `@stream_servers` refetch on success; verify via tests or `mix phx.server`
- [x] 2.4 Rework the `:assign` card: remove the `<form>`, hidden input, and Save button; give each checkbox `phx-click="toggle-assignment"` + `phx-value-application-id` + `phx-value-assigned` (the displayed state) handled by `assign_application`/`unassign_application`, updating `assigned_application_ids` in place; replace Cancel with a Back link; remove the `save_assign` handler; verify via tests or `mix phx.server`
- [x] 2.5 Remove `/stream-servers/:id/edit` from `router.ex` — both the real and `/stream-server-admin`-prefixed mirror route; verify no link/patch still targets it

## 3. Tests and verification

- [x] 3.1 Rework `stream_servers_live_test.exs`: drop edit-form and `save_assign` tests; add coverage for the rename modal (incl. duplicate-name error), description modal, country modal + dropdown, cert hash modal (set and clear), immediate assign/unassign checkbox toggles, the Back link, and the Description column; verify the file passes with `dotenv -e .env.test mix test`
- [x] 3.2 Verify responsiveness: exercise the page at mobile, tablet, and desktop widths — the table scrolls inside its container and modals stay inside the viewport — using the integrated browser (`dotenv -e .env mix phx.server` + browser preview); confirm no horizontal overflow
- [x] 3.3 Validate the full flow in the integrated browser: rename a server, edit a description, pick a country, set and clear a cert hash, toggle applications on and off in the assign view, and remove a server; confirm each persists after reload and `host` has no edit affordance
- [x] 3.4 Run `dotenv -e .env.test mix precommit` and fix any warnings/failures
