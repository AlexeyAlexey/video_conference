# Tasks

## 1. Migration and schema validations

- [x] 1.1 Add a migration in `priv/stream_server_admin_portal_repo/migrations/` dropping `unique_index(:applications, [:name])` and `unique_index(:stream_servers, [:name])` (use `drop index(..., name: ...)` or explicit `up`/`down` so rollback recreates the unique indexes); verify `MIX_ENV=test dotenv -e .env.test mix ecto.migrate` succeeds and `mix ecto.rollback` restores the indexes
- [x] 1.2 Remove `unsafe_validate_unique(:name, Repo)` and `unique_constraint(:name)` from `Application.changeset/2` and `Application.name_changeset/2`, and from `StreamServer.changeset/2` and `StreamServer.name_changeset/2`; keep `validate_required([:name])` and the `host` uniqueness checks; update the changeset `@doc`s that still claim names are unique; verify the project compiles with `mix compile --warnings-as-errors`

## 2. Remove delete paths and event modules

- [x] 2.1 Delete `Applications.remove_application/1`, its `ApplicationWasRemoved` alias, and the `applications/events/application_was_removed.ex` file; update the context `@doc`s; delete the removal/`ApplicationWasRemoved` tests in `applications_test.exs` and add a test that two applications may share a name — verify `dotenv -e .env.test mix test test/lib/video_conference/stream_server_admin_portal/applications_test.exs` passes
- [x] 2.2 Delete `StreamServers.remove_stream_server/1`, its `StreamServerWasRemoved` alias, and the `stream_servers/events/stream_server_was_removed.ex` file; update the context `@doc`s; delete the removal/`StreamServerWasRemoved` tests (including the lock_version-on-removal and stale-removal cases) in `stream_servers_test.exs` and add a test that two servers may share a name while duplicate `host` is still rejected — verify `dotenv -e .env.test mix test test/lib/video_conference/stream_server_admin_portal/stream_servers_test.exs` passes

## 3. LiveView updates

- [x] 3.1 In `ApplicationsLive`, remove the Remove button cell, the `"delete"` `handle_event`, and the now-empty trailing actions column; update `applications_live_test.exs` to drop removal coverage and assert no delete control is rendered — verify its tests pass
- [x] 3.2 In `ApplicationsLive`, add an App ID column as the first data column rendering the full `application.id` UUID in a hidden span with a `navigator.clipboard.writeText` copy button (same pattern as the cert-hash column in `StreamServersLive`); add a list test asserting each row exposes the UUID and copy control — verify its tests pass
- [x] 3.3 In `StreamServersLive`, remove the Remove button, the `"delete"` `handle_event`, and the now-redundant empty header/cell; update `stream_servers_live_test.exs` to drop removal coverage, assert no delete control is rendered, and cover creating/renaming with a duplicate name succeeding — verify its tests pass

## 4. Verification

- [x] 4.1 Exercise both pages in the integrated browser (`dotenv -e .env mix phx.server` + browser preview): confirm no Remove action on either table, App ID column with working copy on applications, duplicate application/server names accepted, and duplicate server host still rejected — verify each behavior persists after reload
- [x] 4.2 Run `dotenv -e .env.test mix precommit` and fix any warnings or failures
