# Portal Public Stream Server Keys Specification

## Purpose

Manages per-application public stream server keys in the stream server
admin portal: UUID-keyed persistence in the portal database where the
record's own id is the public key id, admin CRUD for existing public key
material, and the grouped-by-application listing.

## Requirements

### Requirement: Portal stream server public key record

The system SHALL persist each portal stream server public key in the
portal database with: a UUID primary key, an optional `name`, a required
`key`, a required `application_id` association to a portal application,
an `enabled` flag defaulting to true, and an optional `description`.
`name` SHALL NOT be unique. There SHALL be no `key_id` field — the
record's primary key SHALL serve as the key id — and no `private_key`
field — the system SHALL store only public key material. Once created,
the `key` value SHALL be immutable: no update path SHALL change it.

#### Scenario: Creating a key with required fields

- **WHEN** a portal stream server public key is created with a key and
  an application
- **THEN** it is persisted with `enabled` true and a generated UUID
  that serves as its key id

#### Scenario: Key is required

- **WHEN** a portal stream server public key is saved without a key
- **THEN** the operation fails and the missing key is reported

#### Scenario: Key is immutable

- **WHEN** any update to an existing portal stream server public key is
  attempted with a different key value
- **THEN** the stored key is unchanged

#### Scenario: Name is optional

- **WHEN** a portal stream server public key is created without a name
- **THEN** it is persisted

#### Scenario: Duplicate names allowed

- **WHEN** a key is created or renamed to a name already used by another
  key of the same application
- **THEN** the key is persisted — names are not unique

#### Scenario: Application required

- **WHEN** a key is saved without an application
- **THEN** the operation fails and the missing application is reported

#### Scenario: Deleting an application removes its keys

- **WHEN** a portal application that has stream server public keys is
  deleted
- **THEN** its keys are deleted as well

### Requirement: Portal stream server public keys admin list

An authenticated portal admin SHALL be able to open a page at
`/stream-server-admin/applications/stream-server-public-keys` listing
stream server public keys grouped by portal application, with a
description explaining that each key's id is the key id that identifies
which key verifies the application's signed JWT. Unauthenticated
visitors SHALL be redirected to the portal sign-in page.

#### Scenario: List groups keys by application

- **WHEN** an authenticated portal admin opens
  `/stream-server-admin/applications/stream-server-public-keys`
- **THEN** each portal application's keys are listed under that
  application with name, key id, public key, description, and enabled
  columns

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

#### Scenario: No applications message

- **WHEN** an authenticated portal admin opens
  `/stream-server-admin/applications/stream-server-public-keys` and no
  portal applications exist
- **THEN** a "No applications found" message is shown

#### Scenario: Unauthenticated access

- **WHEN** a visitor opens
  `/stream-server-admin/applications/stream-server-public-keys` without
  a portal admin session
- **THEN** they are redirected to the portal sign-in page

### Requirement: Filter stream server public keys by application

The portal stream server public keys page SHALL offer a filter limiting
the list to a chosen application's keys, including an option for all
applications. The filter control SHALL offer a search field filtering
the application options, and the choice SHALL be reflected in the page
URL.

#### Scenario: Filtering by an application

- **WHEN** a portal admin picks an application in the filter
- **THEN** only that application's keys are listed

#### Scenario: Clearing the filter

- **WHEN** a portal admin picks the all-applications option in the
  filter
- **THEN** every application's keys are listed again

#### Scenario: Searching the filter applications

- **WHEN** a portal admin types in the filter's search field
- **THEN** only applications matching the search text are offered for
  selection

### Requirement: Portal stream server public keys admin management

An authenticated portal admin SHALL be able to add and remove stream
server public keys from the portal page, and to rename a key, edit its
description, change its application, and toggle its enabled flag through
per-field controls — there SHALL be no whole-row edit form. The add form
SHALL offer an application dropdown and accept an existing key.
Validation errors SHALL be shown inline. The page SHALL NOT offer key
pair generation, SHALL NOT accept private key material, and SHALL NOT
offer any control that changes an existing key's public key value.

#### Scenario: Add a key

- **WHEN** a portal admin submits the add form with an application and
  an existing key
- **THEN** the key is persisted and appears in the list with its UUID as
  the key id

#### Scenario: Edit a key

- **WHEN** a portal admin changes a key's name, description,
  application, or enabled flag through its per-field control
- **THEN** the updated attribute is persisted and shown in the list

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
- **THEN** the key is moved to the chosen application's group in the
  list

#### Scenario: Remove a key

- **WHEN** a portal admin picks "Remove" from a key's row actions menu
  and confirms
- **THEN** the key is deleted and disappears from the list

#### Scenario: No control changes the public key value

- **WHEN** a portal admin edits any attribute of an existing key
- **THEN** the key's stored public key value remains unchanged

#### Scenario: Missing application shows error

- **WHEN** a portal admin submits the add form without choosing an
  application
- **THEN** the form shows an inline error and no key is created

### Requirement: Responsive stream server public keys page

The portal stream server public keys page SHALL be usable on mobile,
tablet, and desktop viewports. Data tables SHALL scroll horizontally
inside their container rather than overflowing the page.

#### Scenario: Grouped tables fit narrow screens

- **WHEN** the stream server public keys list is viewed on a narrow
  viewport
- **THEN** the page does not overflow horizontally and each table
  scrolls inside its container

#### Scenario: Modals and menus fit narrow screens

- **WHEN** a modal or a key's row actions menu is opened on a narrow
  viewport
- **THEN** it renders inside the viewport without overflowing or being
  clipped off-screen
