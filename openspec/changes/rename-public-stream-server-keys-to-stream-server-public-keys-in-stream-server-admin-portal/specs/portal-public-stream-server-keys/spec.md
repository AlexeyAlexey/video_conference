# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: Portal public stream server key record`
- TO: `### Requirement: Portal stream server public key record`
- FROM: `### Requirement: Portal public keys admin list`
- TO: `### Requirement: Portal stream server public keys admin list`
- FROM: `### Requirement: Filter public keys by application`
- TO: `### Requirement: Filter stream server public keys by application`
- FROM: `### Requirement: Portal public keys admin management`
- TO: `### Requirement: Portal stream server public keys admin management`
- FROM: `### Requirement: Responsive public keys page`
- TO: `### Requirement: Responsive stream server public keys page`

## MODIFIED Requirements

### Requirement: Portal stream server public key record

The system SHALL persist each portal stream server public key in the
portal database with: a UUID primary key, an optional `name`, a `key`, a
required `application_id` association to a portal application, a
`enabled` flag defaulting to true, and an optional `description`.
`name` SHALL NOT be unique. There SHALL be no `key_id` field — the
record's primary key SHALL serve as the key id — and no `private_key`
field — the system SHALL store only public key material.

#### Scenario: Creating a key with required fields

- **WHEN** a portal stream server public key is created with a key and
  an application
- **THEN** it is persisted with `enabled` true and a generated UUID
  that serves as its key id

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
  application with name, key id, description, and enabled status

#### Scenario: Public key id is the record id

- **WHEN** the list renders a key
- **THEN** the key id column shows the key record's UUID with a
  copy-to-clipboard control next to it

#### Scenario: Copying a public key id

- **WHEN** a portal admin clicks the copy control next to a key's key id
- **THEN** the key record's UUID is copied to the clipboard

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

An authenticated portal admin SHALL be able to add, edit, and remove
stream server public keys from the portal page. The add form SHALL offer
an application dropdown and accept an existing key. Validation errors
SHALL be shown inline. The page SHALL NOT offer key pair generation and
SHALL NOT accept private key material.

#### Scenario: Add a key

- **WHEN** a portal admin submits the add form with an application and
  an existing key
- **THEN** the key is persisted and appears in the list with its UUID as
  the key id

#### Scenario: Edit a key

- **WHEN** a portal admin submits the edit form for a key
- **THEN** the updated attributes are persisted and shown in the list

#### Scenario: Remove a key

- **WHEN** a portal admin confirms removal of a key
- **THEN** the key is deleted and disappears from the list

#### Scenario: Missing application shows error

- **WHEN** a portal admin submits the form without choosing an
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
