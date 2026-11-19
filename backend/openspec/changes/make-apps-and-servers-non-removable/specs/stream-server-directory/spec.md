# Spec Delta

## ADDED Requirements

### Requirement: Portal stream server records

The system SHALL persist each portal stream server with a UUID primary
key, a non-empty `name`, an optional `description`, a unique `host`
address string (ip, domain, or ip:port) that is immutable after
creation, an optional `country` location code, an optional `settings`
map defaulting to an empty map, an optional `cert_hash`, and a
`lock_version` integer defaulting to 1. The `host` SHALL be the
server's unique identifier; names need not be unique.

#### Scenario: Creating a stream server

- **WHEN** a portal admin creates a stream server with a name and host
- **THEN** the server is persisted with a generated UUID, an empty
  settings map, and `lock_version` 1

#### Scenario: Duplicate name allowed

- **WHEN** a portal admin creates or renames a stream server using a
  name that another portal stream server already has
- **THEN** the change is accepted, since `host` is the identifier

#### Scenario: Duplicate host rejected

- **WHEN** a portal admin creates a stream server using a host that
  another portal stream server already has
- **THEN** the change is rejected with a validation error

#### Scenario: Host cannot be changed after creation

- **WHEN** a portal admin edits a persisted stream server
- **THEN** no edit affordance for `host` is offered and the stored
  `host` remains unchanged

### Requirement: Optimistic concurrency for stream server updates

Every update of a portal stream server SHALL be guarded by the
record's `lock_version`: the write succeeds only when the persisted
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

### Requirement: Managing portal stream servers

An authenticated portal admin SHALL be able to add and edit portal
stream servers from the list page. Portal stream servers SHALL NOT be
removable: the list SHALL offer no delete action and the system SHALL
provide no operation that deletes a stream server record. Each editable
field — name, description, country, and certificate hash — SHALL be
edited through its own modal opened from the row. Validation errors
SHALL be shown inline.

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

#### Scenario: Invalid form shows errors

- **WHEN** a portal admin submits the stream server form or a field
  edit modal with invalid data
- **THEN** the form or modal is re-rendered with inline validation
  errors

### Requirement: Application assignments

The system SHALL record a many-to-many assignment between portal stream
servers and applications. An authenticated portal admin SHALL be able
to assign and unassign applications to a stream server from a dedicated
assign view where toggling an application's checkbox persists the
change immediately, and SHALL see each server's assigned applications
in the list.

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

## REMOVED Requirements

### Requirement: Portal stream server record

**Reason**: `name` is no longer unique — `host` is the identifier — so
the record contract is restated as `Portal stream server records`
without the uniqueness clause or the duplicate-name scenario.
**Migration**: Existing records remain valid; dropping the
`stream_servers_name_index` requires no data change.

### Requirement: Optimistic concurrency for portal stream servers

**Reason**: Stream servers can no longer be deleted, so the
concurrency contract is restated as `Optimistic concurrency for stream
server updates` without the stale-delete scenario.
**Migration**: `lock_version` columns and values are unchanged.

### Requirement: Portal stream server management

**Reason**: Stream servers can no longer be removed, so the management
contract is restated as `Managing portal stream servers` without the
removal scenario.
**Migration**: Existing servers are unaffected.

### Requirement: Application assignment

**Reason**: Applications and stream servers can no longer be deleted,
so the cascade-delete clause and its scenario do not apply; the
contract is restated as `Application assignments`.
**Migration**: The `on_delete: :delete_all` foreign keys remain in
place — they are simply unreachable.

### Requirement: Event emitted on stream server removal

**Reason**: Portal stream servers can no longer be removed, so a
removal event can never be emitted. The `StreamServerWasRemoved`
event module is deleted along with the delete path.
**Migration**: Historical `StreamServerWasRemoved` rows in the `events`
table, if any exist, are left in place but become undecodable — no
configured listener or caller queries that event type.
