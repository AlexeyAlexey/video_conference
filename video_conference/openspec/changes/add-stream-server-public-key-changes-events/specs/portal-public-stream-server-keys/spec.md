# Spec Delta

## MODIFIED Requirements

### Requirement: Event emitted on stream server public key creation

Creating a portal stream server public key SHALL append a
`StreamServerPublicKeyWasAdded` to the event store in the same database
transaction as the key's insert. The event SHALL carry the created
key's `id` as its `stream_id` and `id`, plus its `application_id`,
`name`, `key`, `enabled`, `description`, and `lock_version` values.

#### Scenario: Creation appends an added event

- **WHEN** a portal stream server public key is created
- **THEN** exactly one `StreamServerPublicKeyWasAdded` is stored with
  the new key's `id` as its `stream_id`, as the first event on that
  stream

#### Scenario: Event carries the created key's values

- **WHEN** a stored `StreamServerPublicKeyWasAdded` is read back
- **THEN** it contains the created key's `id` as both `stream_id` and
  `id`, plus its `application_id`, `name`, `key`, `enabled`,
  `description`, and `lock_version` at creation time

#### Scenario: Key and event are atomic

- **WHEN** the event append fails while a key is being created
- **THEN** the key is not persisted

## ADDED Requirements

### Requirement: Stream server public key lifecycle events

Enable, disable, remove, and move mutations of a portal stream server
public key SHALL each append a matching domain event —
`StreamServerPublicKeyWasEnabled`, `StreamServerPublicKeyWasDisabled`,
`StreamServerPublicKeyWasRemoved`, `StreamServerPublicKeyWasMoved` — to
the key's stream in the same transaction as the record change. Renames
and description edits SHALL append no event.

#### Scenario: Enabling a key emits an enabled event

- **WHEN** a portal stream server public key is enabled
- **THEN** a `StreamServerPublicKeyWasEnabled` event is stored on the
  key's stream

#### Scenario: Disabling a key emits a disabled event

- **WHEN** a portal stream server public key is disabled
- **THEN** a `StreamServerPublicKeyWasDisabled` event is stored on the
  key's stream

#### Scenario: Removing a key emits a removed event

- **WHEN** a portal stream server public key is removed
- **THEN** a `StreamServerPublicKeyWasRemoved` event is stored on the
  key's stream as its tombstone

#### Scenario: Moving a key emits a moved event with both applications

- **WHEN** a portal stream server public key is moved to another
  application
- **THEN** a `StreamServerPublicKeyWasMoved` event is stored on the
  key's stream carrying the source application as
  `from_application_id` and the destination application as
  `to_application_id`

#### Scenario: Toggling an already-set flag still emits

- **WHEN** a portal stream server public key is enabled while already
  enabled, or disabled while already disabled
- **THEN** the matching `StreamServerPublicKeyWasEnabled` or
  `StreamServerPublicKeyWasDisabled` event is still stored

#### Scenario: Rename and description edits emit no event

- **WHEN** a portal stream server public key is renamed or its
  description is edited
- **THEN** no event is stored for that mutation

#### Scenario: Failed mutation records no event

- **WHEN** a key mutation fails, for example a missing application or a
  stale `lock_version`
- **THEN** no event is stored for that mutation and the key record is
  unchanged

### Requirement: Stream server public key events carry lock_version

Every stream server public key event SHALL carry the key's
`lock_version` after the mutation it describes: 1 for
`StreamServerPublicKeyWasAdded`, the incremented value for updates, and
the value the delete matched for `StreamServerPublicKeyWasRemoved`.

#### Scenario: Add event carries initial lock_version

- **WHEN** a portal stream server public key is created
- **THEN** its `StreamServerPublicKeyWasAdded` event's `lock_version`
  is 1

#### Scenario: Update events carry the incremented lock_version

- **WHEN** a key whose `lock_version` is N is enabled, disabled, or
  moved to another application
- **THEN** the stored event's `lock_version` is N + 1

#### Scenario: Removed event carries the matched lock_version

- **WHEN** a key whose `lock_version` is N is removed
- **THEN** its `StreamServerPublicKeyWasRemoved` event's `lock_version`
  is N
