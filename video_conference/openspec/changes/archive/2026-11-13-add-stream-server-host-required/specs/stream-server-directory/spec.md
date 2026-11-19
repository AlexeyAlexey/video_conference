# Spec Delta

## MODIFIED Requirements

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
