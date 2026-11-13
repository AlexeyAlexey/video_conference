# Tasks

## 1. Schema and migration

- [x] 1.1 In `lib/video_conference/stream_server_admin_portal/stream_servers/stream_server.ex`, change `changeset/2` to `validate_required([:name, :host])` and update its `@doc` to say `host` is required; verify `mix compile` succeeds
- [x] 1.2 Add a portal migration `priv/stream_server_admin_portal_repo/migrations/<timestamp>_require_host_on_stream_servers.exs` that runs `alter table(:stream_servers) do modify :host, :string, null: false, from: {:string, null: true} end`; verify `dotenv -e .env mix ecto.migrate` applies it against the portal repo and `host` is `NOT NULL` afterward
- [x] 1.3 Update `stream_server_fixture/1` in `test/support/fixtures/stream_server_admin_portal_fixtures.exs` to include a unique default host (e.g. `"#{unique_stream_server_name()}.example.test"` or a host derived from the unique-name counter); verify the existing portal stream servers tests still pass

## 2. Validation coverage

- [x] 2.1 Add a test in `test/lib/video_conference/stream_server_admin_portal/stream_servers_test.exs` asserting `create_stream_server/1` with no host and with a blank host returns `{:error, changeset}` with `host: ["can't be blank"]` and persists nothing; verify the test passes
- [x] 2.2 Add a test in `test/video_conference_web/stream_server_admin_portal/live/stream_servers_live_test.exs` asserting submitting the new stream server form with a blank host re-renders the form with an inline host error and no server appears in the list; verify the test passes

## 3. Form UI

- [x] 3.1 In `lib/video_conference_web/stream_server_admin_portal/live/stream_servers_live.ex`, add `required` to the host `<.input>` in the new stream server form (matching the name input); verify the rendered form shows host as required and the LiveView test from 2.2 passes

## 4. Verification

- [x] 4.1 Run `dotenv -e .env.test mix precommit` and fix any warnings or failures

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
