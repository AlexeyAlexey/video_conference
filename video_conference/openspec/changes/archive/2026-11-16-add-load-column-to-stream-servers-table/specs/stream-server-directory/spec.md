# Spec Delta

## ADDED Requirements

### Requirement: Portal stream server load

The system SHALL persist each portal stream server's `load` as an
integer from 0 to 100 defaulting to 0, and SHALL reject values outside
that range. The system SHALL provide an operation that sets a server's
`load`; that operation SHALL NOT be guarded by and SHALL NOT increment
`lock_version`, and SHALL append no event. The list SHALL offer no
control to edit `load`.

#### Scenario: Server created with zero load

- **WHEN** a portal stream server is created
- **THEN** it is persisted with `load` 0

#### Scenario: Updating a server's load

- **WHEN** a server's `load` is set to a value from 0 to 100
- **THEN** the value is persisted and the server's `lock_version` is
  unchanged

#### Scenario: Out-of-range load rejected

- **WHEN** a server's `load` is set below 0 or above 100
- **THEN** the update is rejected with a validation error and the
  stored `load` is unchanged

#### Scenario: Load update is not stale-checked

- **WHEN** a server's `load` is set from a copy of the record loaded
  before another update already committed
- **THEN** the `load` update succeeds and the other fields keep their
  persisted values

#### Scenario: Load update emits no event

- **WHEN** a server's `load` is set
- **THEN** no event is stored for that mutation

#### Scenario: Load is read-only in the list

- **WHEN** the stream servers list renders
- **THEN** each server's `load` is displayed and no edit affordance
  for `load` is offered

## MODIFIED Requirements

### Requirement: Portal stream servers list

An authenticated portal admin SHALL be able to open a page at
`/stream-server-admin/stream-servers` listing every portal stream
server with its name, host, country flag, description, certificate
hash presence, load, and assigned applications. Unauthenticated
visitors SHALL be redirected to the portal sign-in page.

#### Scenario: Viewing the stream servers list

- **WHEN** an authenticated portal admin opens
  `/stream-server-admin/stream-servers`
- **THEN** every portal stream server is shown with its name, host,
  country flag, description, whether a certificate hash is set, its
  load as a progress bar with the numeric percentage, and its assigned
  applications

#### Scenario: Unauthenticated visitor redirected

- **WHEN** a visitor without a portal admin session opens
  `/stream-server-admin/stream-servers`
- **THEN** they are redirected to the portal sign-in page
