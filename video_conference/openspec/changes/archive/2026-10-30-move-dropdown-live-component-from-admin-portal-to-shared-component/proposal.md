# Proposal

## Why

`VideoConferenceWeb.AdminPortal.DropdownComponent` lives under the admin
portal namespace even though it is a generic form control with no
admin-specific behavior. Its placement signals "admin only", so non-admin
LiveViews either cannot discover it or must reach across the admin portal
boundary to reuse it.

## What Changes

- Move the component from
  `lib/video_conference_web/admin_portal/dropdown_component.ex` to
  `lib/video_conference_web/components/dropdown_component.ex`, alongside
  `CoreComponents`.
- Rename the module `VideoConferenceWeb.AdminPortal.DropdownComponent` to
  `VideoConferenceWeb.DropdownComponent` — a **BREAKING** change for all
  call sites (update aliases in the two admin LiveViews that use it).
- Update the component's `@moduledoc` so it no longer describes itself as
  admin-portal-specific.
- Move and rename the test file
  `test/video_conference_web/admin_portal/dropdown_component_test.exs` to
  `test/video_conference_web/components/dropdown_component_test.exs` with a
  matching test module name.
- Update the `liveview-custom-dropdown` skill
  (`.devin/skills/liveview-custom-dropdown/SKILL.md`) to reference the new
  module name and file path.
- No behavioral changes to the component itself — the public assign API,
  events, DOM-id convention, and rendering stay identical.

## Capabilities

### New Capabilities

### Modified Capabilities

- `custom-dropdown`: the capability's framing changes from "the admin
  portal SHALL provide" to "the application SHALL provide" a shared
  reusable dropdown control, reflecting its promotion from an admin portal
  component to a shared `VideoConferenceWeb` component.

## Impact

- **Code:** `dropdown_component.ex` move + module rename; alias updates in
  `lib/video_conference_web/admin_portal/live/stream_servers_live.ex` and
  `lib/video_conference_web/admin_portal/live/public_stream_server_keys_live.ex`;
  test file move + rename.
- **Docs/skills:** `.devin/skills/liveview-custom-dropdown/SKILL.md`
  references updated.
- **No API, dependency, database, or routing changes.** The component is
  referenced only via aliases inside the codebase; there are no external
  consumers.
