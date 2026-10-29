# Proposal

## Why

The admin portal currently has two hand-rolled copies of the same custom
button+listbox dropdown — a searchable one (country picker in
`StreamServersLive`) and a plain one (stream-server picker in
`PublicStreamServerKeysLive`). Native `<select>` is not an option: in Chrome
mobile/responsive mode its popup renders detached at a wrong position. The
duplicated markup, assigns, and event handlers already diverge (search,
empty option, error handling), and every future form that needs a dropdown
would copy the pattern a third time.

## What Changes

- New reusable `Phoenix.LiveComponent` that encapsulates the custom
  dropdown: open/close state, optional search filter, optional empty
  ("None") choice, selected-option highlighting, inline error display, and
  the hidden input that binds the picked value to the enclosing form.
- Component-to-parent communication follows the "Unifying LiveView and
  LiveComponent communication" pattern: the component invokes an `on_change`
  callback assign instead of hard-coding `send(self(), ...)`, so the parent
  (a LiveView today, possibly another component later) decides how the picked
  value is delivered.
- Replace the inline dropdown in `PublicStreamServerKeysLive` (stream
  server field, no search) with the new component.
- Replace the inline dropdown in `StreamServersLive` (country field, with
  search and empty option) with the new component.
- Update the `liveview-custom-dropdown` skill so it documents the component
  API instead of the copy-paste pattern.
- Component-level tests plus updated LiveView tests for both pages.

No changes to persisted data, routes, or externally visible behavior beyond
unifying the control.

## Capabilities

### New Capabilities

- `custom-dropdown`: A reusable custom dropdown/select form control for the
  admin portal — a stateful LiveComponent that renders a daisyUI-styled
  button+listbox, owns its open/search state, emits the picked value through
  an injectable callback, binds the value to the enclosing form via a hidden
  input, and supports optional filtering and an empty choice. Never a native
  `<select>`.

### Modified Capabilities

None — the stream-servers and stream-server-public-keys requirements (a
searchable country choice, a stream-server dropdown) stay behaviorally
identical; only the implementation is consolidated.

## Impact

- **Code:** new `DropdownComponent` (admin portal components), edits to
  `PublicStreamServerKeysLive` and `StreamServersLive` (removed handlers,
  assigns, markup).
- **Docs:** `.devin/skills/liveview-custom-dropdown/SKILL.md` rewritten
  around the component API.
- **Tests:** new component tests; existing LiveView tests keep passing —
  DOM ids (`stream-server-dropdown-button`, `country-option-*`, etc.) are
  preserved by the component.
- **Dependencies:** none.
