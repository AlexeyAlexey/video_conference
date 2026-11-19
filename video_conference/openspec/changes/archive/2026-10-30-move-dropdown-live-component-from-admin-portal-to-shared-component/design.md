# Design

## Context

`VideoConferenceWeb.AdminPortal.DropdownComponent` is a stateful
LiveComponent (`use VideoConferenceWeb, :live_component`) that lives under
the admin portal directory but contains nothing admin-specific. Its only
dependencies are `VideoConferenceWeb` component infrastructure (the `.icon`
component, `translate_error/1`) — both available to any module under
`VideoConferenceWeb`. See proposal.md for motivation.

Current consumers (found via repo-wide search for `DropdownComponent`):

- `lib/video_conference_web/admin_portal/live/stream_servers_live.ex` —
  `alias VideoConferenceWeb.AdminPortal.DropdownComponent`
- `lib/video_conference_web/admin_portal/live/public_stream_server_keys_live.ex` —
  same alias
- `test/video_conference_web/admin_portal/dropdown_component_test.exs` —
  component test driven through a minimal host LiveView via `live_isolated/3`
- `.devin/skills/liveview-custom-dropdown/SKILL.md` — documents module name
  and paths
- Archived openspec change docs (historical, not updated)

## Goals / Non-Goals

**Goals:**

- Relocate the component to the shared components directory and rename it
  so it is discoverable and usable by any LiveView.
- Keep behavior, public assigns, events, and DOM ids identical — existing
  admin forms must work unchanged after updating the alias.
- Keep docs (moduledoc, skill) consistent with the new location.

**Non-Goals:**

- No changes to the component's rendering, events, or assign API.
- No new dropdown features and no refactor of the component internals
  beyond the module rename and moduledoc wording.
- Not folding the component into `CoreComponents` (see Decisions).
- Archived openspec change documents are historical records and are not
  rewritten.

## Decisions

### Target location and module name

Move to `lib/video_conference_web/components/dropdown_component.ex` as
`VideoConferenceWeb.DropdownComponent`.

- **Alternative: keep a `Components` namespace** (e.g.
  `VideoConferenceWeb.Components.DropdownComponent`). Rejected: this
  project puts shared components directly under `VideoConferenceWeb`
  (`CoreComponents`, `Layouts`), so `VideoConferenceWeb.DropdownComponent`
  matches convention.
- **Alternative: merge into `CoreComponents` as a function component.**
  Rejected: the control is stateful (open/search state, `handle_event`s
  with `phx-target={@myself}`); making it a function component would
  redesign it, which is out of scope. Also `CoreComponents` is imported
  into every template and mixing in a LiveComponent would be surprising.
- **Alternative: leave it under `AdminPortal` and document reuse.** That
  is the status quo this change exists to fix.

### Import vs alias at call sites

Keep the existing pattern: each consuming LiveView aliases the module and
renders `<.live_component module={DropdownComponent} ...>`. Only the alias
targets change. Do not add a global import — the component needs `id` and
`on_change` assigns per usage, so `<.live_component>` stays explicit.

### Moduledoc wording

Update the `@moduledoc` (which currently says "for admin portal forms") to
describe it as an application-wide form control. The usage examples stay
valid.

### Test relocation

Move the test to `test/video_conference_web/components/dropdown_component_test.exs`
and rename the test module to `VideoConferenceWeb.DropdownComponentTest`,
matching the `test/` directory's mirroring of `lib/`.

### Skill update

Update `.devin/skills/liveview-custom-dropdown/SKILL.md`: module name,
file path, test path, and the front-matter description wording so it no
longer reads as admin-portal-only. The usage recipes are unchanged.

## Risks / Trade-offs

- [Missed reference to the old module name] → repo-wide search for
  `AdminPortal.DropdownComponent` and `DropdownComponent` after the move;
  `mix compile` fails loudly on any stale alias, and `mix precommit`
  (warnings as errors + tests) is the final gate.
- [The move is a breaking rename for any unindexed consumer] → none exist
  in this repo; there are no external consumers of this namespace.
- [Skill/docs drift] → the skill update is an explicit task, not an
  afterthought.
