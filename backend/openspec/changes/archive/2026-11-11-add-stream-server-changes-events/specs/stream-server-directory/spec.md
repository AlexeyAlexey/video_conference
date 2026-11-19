# Spec Delta

## ADDED Requirements

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
