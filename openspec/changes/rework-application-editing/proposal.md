# Proposal

## Why

The applications page in the stream server admin portal edits every
attribute of an application through a single full-row edit form. The
enabled flag shows as raw "Yes"/"No" text and can only be changed by
submitting that form. Finer-grained, per-field editing matches how the
stream servers and stream server public keys pages were already
reworked, and the `applications` table lacks the `lock_version`
optimistic-concurrency protection those tables have.

## What Changes

- **BREAKING (UI flow)**: The whole-row Edit action and the
  `/stream-server-admin/applications/:id/edit` route are removed.
  Editing happens through targeted per-field modals instead.
- **Name** gets a pencil icon that opens a rename modal (required +
  uniqueness validations kept). **Description** gets a pencil that
  opens a textarea modal.
- The **Enabled** column replaces "Yes"/"No" text with a live checkbox
  (checked = enabled) that toggles the application immediately on
  click.
- `applications` gains a `lock_version` integer column (default 1)
  with `Ecto.Changeset.optimistic_lock/3` applied on every
  update/delete path; stale conflicts surface as changeset errors
  rather than `Ecto.StaleEntryError` crashes — the same treatment the
  stream servers and public keys tables have.
- The context gains granular update functions —
  `rename_application/2`, `edit_application_description/2`,
  `enable_application/1`, `disable_application/1` — and the generic
  `update_application/2` is removed along with its only caller (the
  `:edit` form).
- Modals are event-driven (no new routes), reusing the private `modal`
  component pattern from the public keys and stream servers pages.
- Row actions keep **Remove** as a plain inline button — no `⋯` menu,
  matching the stream servers page when only non-modal actions remain.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `stream-server-applications`: the application-record requirement
  gains a `lock_version` column; a new optimistic-concurrency
  requirement covers update/delete; the management requirement
  replaces full-row edit with per-field modals and replaces the
  enabled flag display with an immediately-persisting checkbox.

## Impact

- **Code**:
  `lib/video_conference_web/stream_server_admin_portal/live/applications_live.ex`
  (major rework),
  `lib/video_conference/stream_server_admin_portal/applications.ex`
  (new functions, removed updater),
  `lib/video_conference/stream_server_admin_portal/applications/application.ex`
  (per-field changesets + `lock_version`),
  `lib/video_conference_web/stream_server_admin_portal/router.ex`
  (`:edit` route removed, both real and mirror).
- **Migration**: `lock_version` column (default 1, not null) on
  `applications` in `priv/stream_server_admin_portal_repo/migrations/`.
- **Tests**:
  `test/video_conference_web/stream_server_admin_portal/live/applications_live_test.exs`,
  `test/lib/video_conference/stream_server_admin_portal/applications_test.exs`.
- **Routes**: `GET /stream-server-admin/applications/:id/edit`
  disappears; `:new` and `:index` are unchanged.
- No event store changes — application mutations do not emit events.
