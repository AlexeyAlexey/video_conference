# Stream Server Directory Specification

## Purpose

Maintains the stream server admin portal's registry of physical stream
servers available to carry video, audio, and event streams, and records
which applications each server is assigned to.

## Requirements

### Requirement: Portal stream server record

The system SHALL persist each portal stream server with a UUID primary
key, a unique non-empty `name`, an optional `description`, a unique
non-empty `host` address string (ip, domain, or ip:port) that is
required at creation and immutable after creation, an optional `country`
location code, an optional `settings` map defaulting to an empty map, an
optional `cert_hash`, and a `lock_version` integer defaulting to 1.

#### Scenario: Creating a stream server

- **WHEN** a portal admin creates a stream server with a name and host
- **THEN** the server is persisted with a generated UUID, an empty
  settings map, and `lock_version` 1

#### Scenario: Duplicate name rejected

- **WHEN** a portal admin creates or renames a stream server using a
  name that another portal stream server already has
- **THEN** the change is rejected with a validation error

#### Scenario: Duplicate host rejected

- **WHEN** a portal admin creates a stream server using a host that
  another portal stream server already has
- **THEN** the change is rejected with a validation error

#### Scenario: Missing host rejected

- **WHEN** a portal admin creates a stream server without a host or
  with a blank host
- **THEN** the change is rejected with a validation error and no server
  is persisted

#### Scenario: Host cannot be changed after creation

- **WHEN** a portal admin edits a persisted stream server
- **THEN** no edit affordance for `host` is offered and the stored
  `host` remains unchanged

### Requirement: Optimistic concurrency for portal stream servers

Every update or delete of a portal stream server SHALL be guarded by
the record's `lock_version`: the write succeeds only when the persisted
`lock_version` still matches the version the caller loaded, and a
successful write increments it. A write attempted against a stale
record version SHALL fail and report the record as stale through the
normal error channel — it SHALL NOT raise an unhandled exception.

#### Scenario: Successful update increments lock version

- **WHEN** a portal stream server is renamed, re-described, has its
  country changed, or has its certificate hash updated
- **THEN** its persisted `lock_version` increases by one

#### Scenario: Stale update is rejected

- **WHEN** a stream server is updated using a copy loaded before
  another update already committed
- **THEN** the operation fails reporting the record as stale and the
  persisted values are unchanged

#### Scenario: Stale delete is rejected

- **WHEN** a stream server is deleted using a copy loaded before
  another update already committed
- **THEN** the operation fails reporting the record as stale and the
  server remains persisted

### Requirement: Portal stream server country location

The system SHALL store an optional `country` on each portal stream
server as an ISO 3166-1 alpha-2 code. The new stream server form and
the country edit modal SHALL offer the country as a searchable choice
of flag + country-name options including an empty choice, and the list
SHALL display each server's flag.

#### Scenario: Picking a country

- **WHEN** a portal admin opens the country selector for a stream
  server
- **THEN** a searchable list of flag + country-name options is shown
  including an empty choice

#### Scenario: Flag shown in the list

- **WHEN** the stream servers list renders a server with a country
- **THEN** that country's flag is displayed for the server

### Requirement: Portal stream server certificate hash

The system SHALL store the stream server's TLS certificate hash in a
`cert_hash` column, and SHALL allow it to be set or cleared when the
server is created or edited, for servers that use a self-signed
certificate.

#### Scenario: Setting a certificate hash

- **WHEN** a portal admin saves a stream server with a certificate hash
- **THEN** the hash is persisted on the server's `cert_hash` column

#### Scenario: Clearing a certificate hash

- **WHEN** a portal admin edits a stream server and saves it with a
  blank certificate hash
- **THEN** the stored `cert_hash` is cleared

#### Scenario: Copying the certificate hash

- **WHEN** the stream servers list renders a server with a certificate
  hash
- **THEN** a copy control is offered that copies the hash to the
  clipboard

### Requirement: Portal stream servers list

An authenticated portal admin SHALL be able to open a page at
`/stream-server-admin/stream-servers` listing every portal stream
server with its name, host, country flag, description, certificate hash
presence, and assigned applications. Unauthenticated visitors SHALL be
redirected to the portal sign-in page.

#### Scenario: Viewing the stream servers list

- **WHEN** an authenticated portal admin opens
  `/stream-server-admin/stream-servers`
- **THEN** every portal stream server is shown with its name, host,
  country flag, description, whether a certificate hash is set, and its
  assigned applications

#### Scenario: Unauthenticated visitor redirected

- **WHEN** a visitor without a portal admin session opens
  `/stream-server-admin/stream-servers`
- **THEN** they are redirected to the portal sign-in page

### Requirement: Portal stream server management

An authenticated portal admin SHALL be able to add, edit, and remove
portal stream servers from the list page. The new stream server form
SHALL require a `name` and a `host`. Each editable field — name,
description, country, and certificate hash — SHALL be edited through
its own modal opened from the row. Validation errors SHALL be shown
inline.

#### Scenario: Adding a stream server

- **WHEN** a portal admin submits the new stream server form with valid
  data
- **THEN** the server is created and shown in the list

#### Scenario: Adding a stream server without a host

- **WHEN** a portal admin submits the new stream server form with a
  blank host
- **THEN** the form is re-rendered with an inline validation error on
  the host field and no server is created

#### Scenario: Editing a stream server

- **WHEN** a portal admin opens a field's edit modal, changes the
  value, and saves
- **THEN** only that field's stored value is updated

#### Scenario: Clearing the certificate hash

- **WHEN** a portal admin saves the certificate hash modal with a blank
  value
- **THEN** the stored `cert_hash` is cleared

#### Scenario: Removing a stream server

- **WHEN** a portal admin removes a stream server
- **THEN** the server and its application assignments are deleted

#### Scenario: Invalid form shows errors

- **WHEN** a portal admin submits the stream server form or a field
  edit modal with invalid data
- **THEN** the form or modal is re-rendered with inline validation
  errors

### Requirement: Application assignment

The system SHALL record a many-to-many assignment between portal stream
servers and applications. An authenticated portal admin SHALL be able to
assign and unassign applications to a stream server from a dedicated
assign view where toggling an application's checkbox persists the
change immediately, and SHALL see each server's assigned applications
in the list. Deleting an application or a stream server SHALL remove
its assignments.

#### Scenario: Assigning applications

- **WHEN** a portal admin checks an application's checkbox in a
  server's assign view
- **THEN** that application is assigned to the server without any
  further action

#### Scenario: Unassigning an application

- **WHEN** a portal admin unchecks an assigned application's checkbox
  in a server's assign view
- **THEN** that assignment is removed without any further action

#### Scenario: Same server in multiple applications

- **WHEN** a portal admin assigns the same stream server to several
  applications
- **THEN** the server appears as assigned in each of those applications

#### Scenario: Assigned applications shown in list

- **WHEN** the stream servers list renders a server with assigned
  applications
- **THEN** the names of its assigned applications are displayed

#### Scenario: Deleted application removes assignment

- **WHEN** an application assigned to stream servers is deleted
- **THEN** its assignments are removed and the servers remain

### Requirement: Filter stream servers by application

The portal stream servers list SHALL offer a filter limiting the list to
servers assigned to a chosen application, including an option for all
servers and an option for servers with no assigned application. The
filter control SHALL offer a search field filtering the application
options.

#### Scenario: Filtering by an application

- **WHEN** a portal admin picks an application in the filter
- **THEN** only stream servers assigned to that application are listed

#### Scenario: Filtering to unassigned servers

- **WHEN** a portal admin picks the unassigned option in the filter
- **THEN** only stream servers with no assigned application are listed

#### Scenario: Clearing the filter

- **WHEN** a portal admin picks the all-servers option in the filter
- **THEN** every portal stream server is listed again

#### Scenario: Searching the filter applications

- **WHEN** a portal admin types in the filter's search field
- **THEN** only applications matching the search text are offered for
  selection

### Requirement: Responsive stream servers page

The portal stream servers page SHALL be usable on mobile, tablet, and
desktop viewports. Its data table SHALL scroll horizontally inside its
container rather than overflowing the page.

#### Scenario: Mobile viewport

- **WHEN** a portal admin opens the stream servers page on a narrow
  viewport
- **THEN** the page layout adapts and the table scrolls horizontally
  within its container

#### Scenario: Assign view on mobile

- **WHEN** a portal admin opens a server's assign view on a narrow
  viewport
- **THEN** the assign view remains usable and applications can be
  selected

### Requirement: Event emitted on stream server creation

Creating a portal stream server SHALL append a `StreamServerWasAdded`
to the event store in the same database transaction as the server's
insert. The event SHALL carry the created server's `id` as its
`stream_id` and `id`, plus its `name`, `description`, `host`,
`country`, `settings`, `cert_hash`, and `lock_version` values.

#### Scenario: Creation appends an added event

- **WHEN** a portal stream server is created
- **THEN** exactly one `StreamServerWasAdded` is stored with the new
  server's `id` as its `stream_id`, as the first event on that stream

#### Scenario: Event carries the created server's values

- **WHEN** a stored `StreamServerWasAdded` is read back
- **THEN** it contains the created server's `id` as both `stream_id`
  and `id`, plus its `name`, `description`, `host`, `country`,
  `settings`, `cert_hash`, and `lock_version` of 1

#### Scenario: Server and event are atomic

- **WHEN** the event append fails while a server is being created
- **THEN** the server is not persisted

### Requirement: Event emitted on stream server removal

Removing a portal stream server SHALL append a
`StreamServerWasRemoved` to the server's stream in the same
transaction as the delete, as its tombstone. The event SHALL carry the
removed server's `id` as its `stream_id` and `id`, and the
`lock_version` the delete matched.

#### Scenario: Removal appends a removed event

- **WHEN** a portal stream server is removed
- **THEN** a `StreamServerWasRemoved` is stored on the server's stream
  with the server's `id` as its `stream_id`

#### Scenario: Removed event carries the matched lock_version

- **WHEN** a server whose `lock_version` is N is removed
- **THEN** its `StreamServerWasRemoved` event's `lock_version` is N

#### Scenario: Stale removal stores no event

- **WHEN** a removal is attempted with a stale `lock_version`
- **THEN** the removal fails reporting the record as stale and no
  event is stored

### Requirement: Stream server assignment events

Assigning an application to a portal stream server SHALL append a
`StreamServerWasAssignedToApplication`, and unassigning SHALL append a
`StreamServerWasUnassignedFromApplication`, each in the same
transaction as the assignment change. The assignment SHALL increment
the server's `lock_version`, and each event SHALL carry the server's
`id` as `stream_id` and `id`, the `application_id` involved, and the
incremented `lock_version`.

#### Scenario: Assigning an application emits an assigned event

- **WHEN** an application is assigned to a portal stream server
- **THEN** a `StreamServerWasAssignedToApplication` is stored on the
  server's stream carrying that application's `application_id`

#### Scenario: Unassigning an application emits an unassigned event

- **WHEN** an application is unassigned from a portal stream server
- **THEN** a `StreamServerWasUnassignedFromApplication` is stored on
  the server's stream carrying that application's `application_id`

#### Scenario: Assignment increments the lock version

- **WHEN** an application is assigned to or unassigned from a server
  whose `lock_version` is N
- **THEN** the server's persisted `lock_version` becomes N + 1 and the
  stored event's `lock_version` is N + 1

#### Scenario: No-op assignment still emits

- **WHEN** an already-assigned application is assigned again, or an
  application that is not assigned is unassigned
- **THEN** the matching assignment event is still stored

### Requirement: Cosmetic stream server edits and failed mutations emit no event

Renaming a portal stream server and editing its description, country,
or certificate hash SHALL append no event. A failed mutation SHALL
store no event and leave the record unchanged.

#### Scenario: Field edits emit no event

- **WHEN** a portal stream server is renamed or its description,
  country, or certificate hash is edited
- **THEN** no event is stored for that mutation

#### Scenario: Failed mutation records no event

- **WHEN** a stream server mutation fails, for example a validation
  error or a stale `lock_version`
- **THEN** no event is stored for that mutation and the server record
  is unchanged
