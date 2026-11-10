# Spec Delta

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Portal stream server record

The system SHALL persist each portal stream server with a UUID primary
key, a unique non-empty `name`, an optional `description`, a unique
`host` address string (ip, domain, or ip:port) that is immutable after
creation, an optional `country` location code, an optional `settings`
map defaulting to an empty map, an optional `cert_hash`, and a
`lock_version` integer defaulting to 1.

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

#### Scenario: Host cannot be changed after creation

- **WHEN** a portal admin edits a persisted stream server
- **THEN** no edit affordance for `host` is offered and the stored
  `host` remains unchanged

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
portal stream servers from the list page. Each editable field — name,
description, country, and certificate hash — SHALL be edited through
its own modal opened from the row. Validation errors SHALL be shown
inline.

#### Scenario: Adding a stream server

- **WHEN** a portal admin submits the new stream server form with valid
  data
- **THEN** the server is created and shown in the list

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
servers and applications. An authenticated portal admin SHALL be able
to assign and unassign applications to a stream server from a dedicated
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
