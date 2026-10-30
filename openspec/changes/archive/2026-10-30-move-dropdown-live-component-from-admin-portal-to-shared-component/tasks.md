# Tasks

## 1. Move and rename the component

- [x] 1.1 Move `lib/video_conference_web/admin_portal/dropdown_component.ex`
  to `lib/video_conference_web/components/dropdown_component.ex` (use
  `git mv` to preserve history) and verify the file exists at the new path.
- [x] 1.2 Rename the module to `VideoConferenceWeb.DropdownComponent` and
  update the `@moduledoc` so it describes a shared application-wide form
  control instead of an admin-portal one; keep the usage examples and
  assign docs otherwise intact. Verify with `mix compile` that the module
  compiles under its new name.

## 2. Update call sites

- [x] 2.1 In
  `lib/video_conference_web/admin_portal/live/stream_servers_live.ex`,
  change `alias VideoConferenceWeb.AdminPortal.DropdownComponent` to
  `alias VideoConferenceWeb.DropdownComponent`; verify no other reference
  to the old module remains in the file.
- [x] 2.2 In
  `lib/video_conference_web/admin_portal/live/public_stream_server_keys_live.ex`,
  make the same alias change; verify no other reference to the old module
  remains in the file.
- [x] 2.3 Run a repo-wide search for `AdminPortal.DropdownComponent` and
  verify zero matches remain outside `openspec/changes/archive/` and
  `openspec/changes/move-dropdown-live-component-from-admin-portal-to-shared-component/`.

## 3. Move and rename the test

- [x] 3.1 Move
  `test/video_conference_web/admin_portal/dropdown_component_test.exs` to
  `test/video_conference_web/components/dropdown_component_test.exs` and
  rename the test module (and its `alias`es) to
  `VideoConferenceWeb.DropdownComponent` /
  `VideoConferenceWeb.DropdownComponentTest`. Verify
  `dotenv -e .env.test mix test test/video_conference_web/components/dropdown_component_test.exs`
  passes.

## 4. Update the skill

- [x] 4.1 Update `.devin/skills/liveview-custom-dropdown/SKILL.md`:
  replace `VideoConferenceWeb.AdminPortal.DropdownComponent` with
  `VideoConferenceWeb.DropdownComponent`, update the component file path,
  the test file path, and the front-matter description/intro wording so it
  no longer reads as admin-portal-only. Verify a search of the skill file
  for `AdminPortal` returns no stale references (reference implementation
  paths under `admin_portal/live/` stay — those LiveViews still exist
  there).

## 5. Final verification

- [x] 5.1 Run `dotenv -e .env.test mix precommit` and verify it completes
  cleanly (compile with warnings as errors, formatting, tests).
- [x] 5.2 Manually verify both admin pages that render dropdowns (stream
  servers country dropdown and public stream server keys dropdown) still
  open, filter, pick, and submit values — confirming identical behavior
  after the move.
