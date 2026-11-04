# Spec Delta

## ADDED Requirements

### Requirement: Optimistic concurrency for portal stream server public keys

Every update or delete of a portal stream server public key SHALL be
guarded by the record's `lock_version`: the write succeeds only when
the persisted `lock_version` still matches the version the caller
loaded, and a successful write increments it. A write attempted against
a stale record version SHALL fail and report the record as stale
through the normal error channel — it SHALL NOT raise an unhandled
exception.

#### Scenario: Successful update increments lock version

- **WHEN** a portal stream server public key is renamed, re-described,
  moved to another application, or has its enabled flag toggled
- **THEN** its persisted `lock_version` increases by one

#### Scenario: Stale update is rejected

- **WHEN** a key is updated using a copy loaded before another update
  already committed
- **THEN** the operation fails reporting the record as stale and the
  persisted values are unchanged

#### Scenario: Stale delete is rejected

- **WHEN** a key is deleted using a copy loaded before another update
  already committed
- **THEN** the operation fails reporting the record as stale and the
  key remains persisted

### Requirement: Event emitted on stream server public key creation

Creating a portal stream server public key SHALL append a
`StreamServerPublicKeyAddedEvent` to the event store in the same
database transaction as the key's insert. The event SHALL carry the
created key's `id`, its `version` (the key's `lock_version` after
creation), and its `application_id`, `name`, `key`, `enabled`, and
`description` values.

#### Scenario: Creation appends an added event

- **WHEN** a portal stream server public key is created
- **THEN** exactly one `StreamServerPublicKeyAddedEvent` is stored with
  the new key's `id` as the event `id` and the key's `lock_version` as
  the event `version`

#### Scenario: Event carries the created key's values

- **WHEN** a stored `StreamServerPublicKeyAddedEvent` is read back
- **THEN** it contains the created key's `id`, `version`,
  `application_id`, `name`, `key`, `enabled`, and `description` at
  creation time

#### Scenario: Key and event are atomic

- **WHEN** the event append fails while a key is being created
- **THEN** the key is not persisted

## MODIFIED Requirements

### Requirement: Portal stream server public key record

The system SHALL persist each portal stream server public key in the
portal database with: a UUID primary key, an optional `name`, a required
`key`, a required `application_id` association to a portal application,
an `enabled` flag defaulting to true, an optional `description`, and a
`lock_version` integer defaulting to 1.
`name` SHALL NOT be unique. There SHALL be no `key_id` field — the
record's primary key SHALL serve as the key id — and no `private_key`
field — the system SHALL store only public key material. Once created,
the `key` value SHALL be immutable: no update path SHALL change it.

#### Scenario: Creating a key with required fields

- **WHEN** a portal stream server public key is created with a key and
  an application
- **THEN** it is persisted with `enabled` true, `lock_version` 1, and a
  generated UUID that serves as its key id

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
