# Custom Dropdown Specification

## Purpose

Provides a single reusable custom dropdown/select control for admin portal
forms, replacing hand-rolled per-page dropdowns. It exists because native
`<select>` elements render their option popup detached at a wrong position
in Chrome's mobile/responsive mode.

## Requirements

### Requirement: Custom dropdown control

The admin portal SHALL provide a reusable custom dropdown form control that
renders a button showing the current selection and, when opened, a listbox
of options anchored directly beneath the field. It SHALL NOT use a native
`<select>` element.

#### Scenario: Closed dropdown shows the current selection

- **WHEN** a form renders the dropdown with a selected value
- **THEN** the control shows a button displaying the selected option's label
  (or a placeholder when nothing is selected) with a chevron affordance

#### Scenario: Opening the dropdown

- **WHEN** an admin activates the dropdown button
- **THEN** the listbox opens beneath the field showing every option

#### Scenario: No native select rendered

- **WHEN** the dropdown is rendered on any viewport, including small/mobile
- **THEN** no native `<select>` element is present for the field and the
  option list stays anchored to the control

### Requirement: Open and close behavior

The dropdown SHALL toggle open and closed on its button, SHALL close when
the admin clicks outside the control, and SHALL close after an option is
picked. Only the open state renders the listbox.

#### Scenario: Click outside closes

- **WHEN** the dropdown is open and the admin clicks elsewhere on the page
- **THEN** the listbox closes without changing the selected value

#### Scenario: Pick closes and selects

- **WHEN** an admin picks an option from the open listbox
- **THEN** the listbox closes and the picked value becomes the selection

### Requirement: Selection callback

The dropdown SHALL deliver the picked value to its parent through an
injected callback assign rather than a hard-coded message, so it works when
mounted under either a LiveView or another component. The parent SHALL own
the selected value; the component SHALL NOT hold a second copy of it.

#### Scenario: Parent receives the picked value

- **WHEN** an admin picks an option
- **THEN** the injected callback is invoked with the picked value and the
  parent applies it (for example by updating the form changeset)

### Requirement: Form binding

Inside an enclosing form, the dropdown SHALL render a hidden input carrying
the bound field's id, name, and current value, so the picked value is
submitted and validated through the form's normal `phx-change`/`phx-submit`
flow.

#### Scenario: Picked value submits with the form

- **WHEN** an admin picks an option and submits the form
- **THEN** the submitted params contain the picked value under the field's
  name

#### Scenario: Validation error displayed inline

- **WHEN** the bound field has a validation error after the field was used
- **THEN** the error is shown inline beneath the control

### Requirement: Optional search filter

The dropdown SHALL support an optional search input inside the open listbox
for long option lists. When enabled, typing filters the offered options and
the input receives focus when the listbox opens.

#### Scenario: Filtering options

- **WHEN** an admin types in the dropdown's search field
- **THEN** only options matching the search text are offered

### Requirement: Optional empty choice

The dropdown SHALL support an optional empty (for example "None") choice
listed before the real options, for fields that may be left unset.

#### Scenario: Empty choice clears the value

- **WHEN** an admin picks the empty choice
- **THEN** the callback delivers the empty value and the control shows the
  empty-state label

### Requirement: Selection highlighting and accessibility

The open listbox SHALL expose `role="listbox"` with `role="option"` items,
the button SHALL expose `aria-haspopup` and `aria-expanded`, and the
currently selected option SHALL be marked with `aria-selected` and visually
highlighted.

#### Scenario: Selected option is marked

- **WHEN** an admin opens the dropdown while a value is selected
- **THEN** the matching option has `aria-selected="true"` and is visually
  distinguished

### Requirement: Responsive and consistent styling

The dropdown SHALL use the project's Tailwind/daisyUI design system, span
the full field width, scroll its options vertically inside a bounded-height
listbox layered above page content, and remain usable on mobile, tablet,
and desktop viewports.

#### Scenario: Long option list on a small viewport

- **WHEN** the dropdown opens with more options than fit its bounded height
  on a narrow viewport
- **THEN** the listbox scrolls inside its own container without overflowing
  the page
