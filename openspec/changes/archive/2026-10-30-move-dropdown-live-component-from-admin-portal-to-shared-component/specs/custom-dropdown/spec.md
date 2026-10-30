# Spec Delta

## MODIFIED Requirements

### Requirement: Custom dropdown control

The application SHALL provide a shared reusable custom dropdown form
control, available to any LiveView in the application (not only the admin
portal), that renders a button showing the current selection and, when
opened, a listbox of options anchored directly beneath the field. It SHALL
NOT use a native `<select>` element.

#### Scenario: Closed dropdown shows the current selection

- **WHEN** a form renders the dropdown with a selected value
- **THEN** the control shows a button displaying the selected option's label
  (or a placeholder when nothing is selected) with a chevron affordance

#### Scenario: Opening the dropdown

- **WHEN** a user activates the dropdown button
- **THEN** the listbox opens beneath the field showing every option

#### Scenario: No native select rendered

- **WHEN** the dropdown is rendered on any viewport, including small/mobile
- **THEN** no native `<select>` element is present for the field and the
  option list stays anchored to the control

## ADDED Requirements

### Requirement: Shared availability

The dropdown control SHALL live in the shared web component namespace so
that any LiveView — inside or outside the admin portal — can use it
without depending on admin portal modules.

#### Scenario: Non-admin LiveView uses the dropdown

- **WHEN** a LiveView outside the admin portal renders a form containing
  the dropdown
- **THEN** the control renders and behaves identically to its admin portal
  usage, with no admin-portal-specific module reference required

#### Scenario: Admin portal usages keep working

- **WHEN** an existing admin portal form renders the dropdown after the
  move
- **THEN** its selection, filtering, empty-choice, and form-binding
  behavior are unchanged
