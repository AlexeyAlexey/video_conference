# Tasks

## 1. Migration and schema

- [x] 1.1 Create a migration in `priv/stream_server_admin_portal_repo/migrations/` adding `load` `:integer` `null: false` `default: 0` to `stream_servers` plus a `0 <= load <= 100` check constraint; verify `dotenv -e .env mix ecto.migrate` (portal repo) and `dotenv -e .env.test mix ecto.migrate` succeed
- [x] 1.2 Add `field :load, :integer, default: 0` to `StreamServerAdminPortal.StreamServers.StreamServer` and a `load_changeset/2` (cast `:load`, `validate_number` 0–100, **no** `optimistic_lock`); do not add `:load` to `changeset/2`'s cast list — verify `mix compile` succeeds

## 2. Context write path

- [x] 2.1 Add `StreamServers.update_stream_server_load/2` (fetch, `load_changeset`, `Repo.update` — no `stale_error_field`, no `EventStore.append`) in `lib/video_conference/stream_server_admin_portal/stream_servers.ex`; verify the new tests in 2.2 pass
- [x] 2.2 In `test/lib/video_conference/stream_server_admin_portal/stream_servers_test.exs` cover: valid update persists; boundaries 0 and 100 accepted; −1 and 101 rejected with `load` unchanged; `lock_version` not incremented; update succeeds on a stale-loaded record; no event appended — verify `dotenv -e .env.test mix test test/lib/video_conference/stream_server_admin_portal/stream_servers_test.exs` passes

## 3. List page column

- [x] 3.1 Add a `Load` column between `Cert hash` and `Applications` in `StreamServersLive`'s table rendering `<progress class="progress" value={server.load} max="100">` plus the numeric percentage, with stable ids (e.g. `server-load-<id>`) for tests; verify the new tests in 3.2 pass
- [x] 3.2 In `test/video_conference_web/stream_server_admin_portal/live/stream_servers_live_test.exs` assert the `Load` header renders and a row's progress element shows the server's load, and that no load edit control exists; verify `dotenv -e .env.test mix test test/video_conference_web/stream_server_admin_portal/live/stream_servers_live_test.exs` passes

## 4. Final verification

- [x] 4.1 Run `dotenv -e .env.test mix precommit` and fix any pending issues

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
