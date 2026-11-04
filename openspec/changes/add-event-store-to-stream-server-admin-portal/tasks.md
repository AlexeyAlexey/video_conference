# Tasks

## 1. Database and schemas

- [ ] 1.1 Add migration `create_events` under
  `priv/stream_server_admin_portal_repo/migrations/`: integer `seq`
  primary key, `id` binary_id, `version` integer, `event_type` string,
  `payload` blob, `added_at` utc_datetime_usec, and
  `unique_index(:events, [:id, :version])`; verify
  `dotenv -e .env.test mix ecto.migrate` applies it to the portal repo
- [ ] 1.2 Add migration adding `lock_version` (integer, default 1,
  null: false) to `stream_server_public_keys`; verify migrate succeeds
  and existing rows get `lock_version` 1
- [ ] 1.3 Create `StreamServerAdminPortal.EventStore.Event` schema
  (`@primary_key {:seq, :id, autogenerate: true}`, `added_at` field
  `:utc_datetime_usec` with `autogenerate: {DateTime, :utc_now, []}`,
  no `timestamps()`); verify `mix compile` succeeds
- [ ] 1.4 Add `field :lock_version, :integer, default: 1` to
  `StreamServerPublicKey`; verify `mix compile` succeeds

## 2. EventStore context

- [ ] 2.1 Create `StreamServerAdminPortal.EventStore` with
  `append/1,2`: `append(events)` returns a new `Ecto.Multi`,
  `append(multi, events)` inserts one event row per struct
  (`event_type` = `inspect(event.__struct__)`, `payload` =
  `:erlang.term_to_binary(event)`, `id`/`version` from the struct);
  verify a test asserting a transaction with the returned multi
  persists the events with increasing `seq`
- [ ] 2.2 Implement `decode_payload/1` decoding a stored `payload`
  binary via `:erlang.binary_to_term(payload, [:safe])` into the
  original event struct; verify a test round-trips an appended event
  through `term_to_binary`/`decode_payload`
- [ ] 2.3 Implement `get_events(event_names, seq)` filtering
  `event_type in names` and `seq > cursor`, ordering by `seq`, with
  each returned row's `payload` decoded via `decode_payload/1`; verify
  tests cover name filtering, seq-cursor filtering, seq ordering,
  decoded payloads, and the empty result
- [ ] 2.4 Verify a test asserts a duplicate (`id`, `version`) append
  fails with a uniqueness error and stores no second event

## 3. Public key optimistic locking and atomic event emission

- [ ] 3.1 Create
  `StreamServerAdminPortal.Applications.StreamServerPublicKeyAddedEvent`
  as a plain `defstruct` with `id`, `version`, `application_id`,
  `name`, `key`, `enabled`, `description`, plus a
  `new(%StreamServerPublicKey{})` constructor mapping `id` to the key
  id, `version` to the key's `lock_version`, and the snapshot fields;
  verify `mix compile` succeeds and a test asserts `new/1` maps all
  fields
- [ ] 3.2 Apply `optimistic_lock(:lock_version)` inside
  `name_changeset`, `description_changeset`, `application_changeset`,
  `enabled_changeset` (NOT the create `changeset/2`), pass
  `stale_error_field: :lock_version` on the Repo update calls, and wrap
  the delete struct in `change() |> optimistic_lock(:lock_version)`;
  verify tests show `lock_version` increments on each update, new keys
  persist with 1, and stale update/delete return
  `{:error, changeset}` with a stale error instead of raising
- [ ] 3.3 Rewire `create_stream_server_public_key/1` through
  `Ecto.Multi` (`insert` + `merge` calling `EventStore.append` with
  `StreamServerPublicKeyAddedEvent.new(key)`), mapping the transaction
  result back to `{:ok, key}` / `{:error, changeset}`; verify tests
  show the key and one `StreamServerPublicKeyAddedEvent`
  (`id` = key id, `version` = 1, snapshot fields matching) commit
  together, and a failing event append rolls the key back

## 4. Verification

- [ ] 4.1 Run `dotenv -e .env.test mix precommit` and fix any warnings
  or test failures
- [ ] 4.2 Run `openspec validate add-event-store-to-stream-server-admin-portal --strict`
  and fix any reported issues
