# Spec Delta

## ADDED Requirements

### Requirement: Application record

Each application SHALL have a UUID primary key, a name, an optional
description, an enabled flag, and timestamps. The UUID SHALL be the
application's unique identifier; application names need not be unique.

#### Scenario: Create an application

- **WHEN** a portal admin submits a new application with a name and optional description
- **THEN** an application record with a generated UUID id, the enabled flag set to true, and timestamps is persisted

#### Scenario: Duplicate application name allowed

- **WHEN** a portal admin submits an application whose name already exists on another application
- **THEN** the application is created, since the UUID is the identifier

#### Scenario: Blank application name rejected

- **WHEN** a portal admin submits an application without a name
- **THEN** the application is not created and a validation error is shown

### Requirement: Application management

Authenticated portal admins SHALL be able to list all applications and
to create, edit, and enable/disable applications from the portal.
Applications SHALL NOT be removable: the list SHALL offer no delete
action and the system SHALL provide no operation that deletes an
application record. The list SHALL display each application's UUID as
an App ID with a copy-to-clipboard control.

#### Scenario: Applications list

- **WHEN** a portal admin opens the applications page
- **THEN** all applications are listed with their App ID, name, enabled state, and actions to edit — and no delete action

#### Scenario: Copying an App ID

- **WHEN** a portal admin activates the copy control next to an application's App ID
- **THEN** the application's UUID is copied to the clipboard

#### Scenario: Edit an application

- **WHEN** a portal admin updates an application's name, description, or enabled flag
- **THEN** the application record reflects the new values

#### Scenario: Disable an application

- **WHEN** a portal admin disables an enabled application
- **THEN** the application's enabled flag becomes false while its API keys remain stored

### Requirement: Application events

Each application mutation SHALL append a domain event to the
application's event stream in the same transaction as the record
change, so both commit or roll back together. Create, rename,
description edit, enable, and disable append
`ApplicationWasAdded`, `ApplicationWasRenamed`,
`ApplicationDescriptionWasUpdated`, `ApplicationWasEnabled`, and
`ApplicationWasDisabled` respectively.

#### Scenario: Creating an application emits an added event

- **WHEN** an application is created
- **THEN** an `ApplicationWasAdded` event is stored on the created
  application's stream with its `name`, `description`, and `enabled`
  values

#### Scenario: Renaming an application emits a renamed event

- **WHEN** an application is renamed
- **THEN** an `ApplicationWasRenamed` event is stored on the
  application's stream with its new `name`

#### Scenario: Editing a description emits an updated event

- **WHEN** an application's description is updated
- **THEN** an `ApplicationDescriptionWasUpdated` event is stored on the
  application's stream with its new `description`

#### Scenario: Toggling enabled emits the matching event

- **WHEN** an application is enabled or disabled
- **THEN** an `ApplicationWasEnabled` or `ApplicationWasDisabled`
  event is stored on the application's stream

#### Scenario: Failed mutation records no event

- **WHEN** an application mutation fails, for example a blank name
  or a stale `lock_version`
- **THEN** no event is stored for that mutation and the application
  record is unchanged

### Requirement: Application event lock_version

Every application event SHALL carry the application's `lock_version`
after the mutation it describes: 1 for `ApplicationWasAdded` and the
incremented value for updates.

#### Scenario: Add event carries initial lock_version

- **WHEN** an application is created
- **THEN** its `ApplicationWasAdded` event's `lock_version` is 1

#### Scenario: Update events carry the incremented lock_version

- **WHEN** an application whose `lock_version` is N is renamed, its
  description updated, or its enabled flag toggled
- **THEN** the stored event's `lock_version` is N + 1

## REMOVED Requirements

### Requirement: Application records

**Reason**: Application names are no longer unique — the UUID is the
identifier — so the record contract is restated as `Application record`
without the uniqueness clause or the duplicate-name scenario.
**Migration**: Existing records remain valid; dropping the
`applications_name_index` requires no data change.

### Requirement: Application management in the portal

**Reason**: Applications can no longer be removed and the list gains an
App ID column, so the management contract is restated as `Application
management` without the delete scenario.
**Migration**: Existing applications are unaffected; admins who need a
record gone disable it instead of deleting it.

### Requirement: Application lifecycle events

**Reason**: `ApplicationWasRemoved` is deleted along with the delete
path, so the event contract is restated as `Application events`
without the removal scenario.
**Migration**: Historical `ApplicationWasRemoved` rows in the `events`
table, if any exist, are left in place but become undecodable — no
configured listener or caller queries that event type.

### Requirement: Application events carry lock_version

**Reason**: The removed-event scenario no longer applies, so the
contract is restated as `Application event lock_version` covering only
add and update events.
**Migration**: No stored events are changed; existing payloads already
carry `lock_version`.
