# Spec Delta

## ADDED Requirements

### Requirement: Portal stream server public keys page and required application selection

An authenticated portal admin SHALL be able to open a page at
`/stream-server-admin/applications/stream-server-public-keys` for
managing stream server public keys. The page SHALL offer a required
application selection whose searchable options are the application
names. There SHALL be no option to select all applications; until an
application is chosen the page SHALL prompt the admin to pick one and
SHALL NOT list keys or offer adding a key. The chosen application SHALL
be reflected in the page URL.

#### Scenario: Prompt before an application is picked

- **WHEN** an admin opens the page with no application selected
- **THEN** the page shows a prompt to select an application, lists no
  keys, and the add action is unavailable

#### Scenario: Keys listed for the selected application

- **WHEN** an admin picks an application in the selection control
- **THEN** the page lists that application's keys with name, key id,
  public key, description, and enabled columns, and the URL carries the
  chosen application id

#### Scenario: Application preselected from the URL

- **WHEN** an admin opens the page with an application id in the URL
- **THEN** that application is selected and its keys are listed

#### Scenario: No all-applications option

- **WHEN** an admin opens the selection control
- **THEN** no option to list every application's keys is offered

#### Scenario: Searching selection options

- **WHEN** an admin types in the selection control's search field
- **THEN** only applications matching the search text are offered for
  selection

#### Scenario: Public key content is hidden behind a show control

- **WHEN** the list renders a key
- **THEN** the public key column shows a show control instead of the
  key's content

#### Scenario: Showing a public key

- **WHEN** a portal admin clicks the show control in a key's public key
  column
- **THEN** a modal opens showing the full public key content with a
  copy-to-clipboard control

#### Scenario: Copying a public key

- **WHEN** a portal admin clicks the copy control in the public key
  modal
- **THEN** the full public key content is copied to the clipboard

#### Scenario: Public key id is the record id

- **WHEN** the list renders a key
- **THEN** the key id column shows the key record's UUID with a
  copy-to-clipboard control next to it

#### Scenario: Copying a public key id

- **WHEN** a portal admin clicks the copy control next to a key's key id
- **THEN** the key record's UUID is copied to the clipboard

#### Scenario: Enabled shown as a checkbox

- **WHEN** the list renders a key
- **THEN** the enabled column shows a checkbox that is checked when the
  key is enabled and unchecked when it is disabled

#### Scenario: Name has an edit control

- **WHEN** the list renders a key
- **THEN** an edit control is shown next to the key's name

#### Scenario: Description has an edit control

- **WHEN** the list renders a key
- **THEN** an edit control is shown next to the key's description

#### Scenario: Long descriptions are expandable

- **WHEN** a key's description exceeds 50 characters
- **THEN** the list shows a truncated preview ending with `...`, and
  clicking it reveals the full description (and clicking again collapses
  it)

#### Scenario: Descriptions wrap inside their column

- **WHEN** a key's description — truncated or full — is wider than the
  description column, including text without spaces
- **THEN** it wraps inside the column instead of overflowing or
  overlapping other columns

#### Scenario: Unauthenticated access

- **WHEN** a visitor opens
  `/stream-server-admin/applications/stream-server-public-keys` without
  a portal admin session
- **THEN** they are redirected to the portal sign-in page

### Requirement: Portal stream server public keys management

An authenticated portal admin SHALL be able to add a stream server
public key for the selected application through a modal whose form
shows the application read-only. The admin SHALL rename a key, edit its
description, change its application, toggle its enabled flag, and
remove it through per-field controls — no whole-row edit form.
Validation errors SHALL be shown inline. The page SHALL NOT offer key
pair generation, accept private key material, or change an existing
key's public key value.

#### Scenario: Adding a key through the modal

- **WHEN** an admin with an application selected activates "Add key" and
  submits a valid form with an existing public key
- **THEN** the key is persisted under the selected application and
  appears in the list with its UUID as the key id

#### Scenario: Add form shows the selected application

- **WHEN** an admin opens the add form
- **THEN** the selected application's name is shown read-only and no
  application picker is offered

#### Scenario: Rename a key

- **WHEN** a portal admin clicks the edit control next to a key's name
  and submits the modal with a new name
- **THEN** the key's name is updated and shown in the list

#### Scenario: Edit a key's description

- **WHEN** a portal admin clicks the edit control next to a key's
  description and submits the modal with a new description
- **THEN** the key's description is updated and shown in the list

#### Scenario: Toggle a key's enabled flag

- **WHEN** a portal admin clicks a key's enabled checkbox
- **THEN** the key's enabled flag flips and the checkbox reflects the
  new state

#### Scenario: Row actions live in a menu

- **WHEN** a portal admin clicks a key's row actions menu control
- **THEN** a menu opens offering "Change app" and "Remove"

#### Scenario: Change a key's application

- **WHEN** a portal admin picks "Change app" from a key's row actions
  menu, chooses an application in the modal's dropdown, and confirms
- **THEN** the key is moved to the chosen application and disappears
  from the current list

#### Scenario: Remove a key

- **WHEN** a portal admin picks "Remove" from a key's row actions menu
  and confirms
- **THEN** the key is deleted and disappears from the list

#### Scenario: No control changes the public key value

- **WHEN** a portal admin edits any attribute of an existing key
- **THEN** the key's stored public key value remains unchanged

#### Scenario: Missing key shows error

- **WHEN** a portal admin submits the add form without a public key
- **THEN** the form shows an inline error and no key is created

### Requirement: Responsive stream server public keys UI

The portal stream server public keys page SHALL be usable on mobile,
tablet, and desktop viewports. The data table SHALL scroll horizontally
inside its container rather than overflowing the page.

#### Scenario: Table fits narrow screens

- **WHEN** the stream server public keys list is viewed on a narrow
  viewport
- **THEN** the page does not overflow horizontally and the table
  scrolls inside its container

#### Scenario: Modals and menus fit narrow screens

- **WHEN** a modal or a key's row actions menu is opened on a narrow
  viewport
- **THEN** it renders inside the viewport without overflowing or being
  clipped off-screen

## REMOVED Requirements

### Requirement: Portal stream server public keys admin list

**Reason**: The grouped-by-application listing is replaced by a required
single-application selection with a flat key list, so its scenarios no
longer describe the behavior.
**Migration**: Covered by "Portal stream server public keys page and
required application selection".

### Requirement: Filter stream server public keys by application

**Reason**: The optional filter with an all-applications option is
replaced by a required application selection with no all-applications
option.
**Migration**: Covered by "Portal stream server public keys page and
required application selection".

### Requirement: Portal stream server public keys admin management

**Reason**: The add form's application dropdown is replaced by the
required page-level selection injecting the application, and the
route-driven add form becomes a modal, so its scenarios no longer
describe the behavior.
**Migration**: Covered by "Portal stream server public keys
management".

### Requirement: Responsive stream server public keys page

**Reason**: Its scenario describes grouped tables; the page now renders
a single table.
**Migration**: Covered by "Responsive stream server public keys UI".
