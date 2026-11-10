# Spec Delta

## ADDED Requirements

### Requirement: Application lifecycle events

Each application mutation SHALL append a domain event to the
application's event stream in the same transaction as the record
change, so both commit or roll back together. Create, rename,
description edit, enable, disable, and delete append
`ApplicationWasAdded`, `ApplicationWasRenamed`,
`ApplicationDescriptionWasUpdated`, `ApplicationWasEnabled`,
`ApplicationWasDisabled`, and `ApplicationWasRemoved` respectively.

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

#### Scenario: Removing an application emits a removed event

- **WHEN** an application is deleted
- **THEN** an `ApplicationWasRemoved` event is stored on the
  application's stream

#### Scenario: Failed mutation records no event

- **WHEN** an application mutation fails, for example a duplicate name
  or a stale `lock_version`
- **THEN** no event is stored for that mutation and the application
  record is unchanged

### Requirement: Application events carry lock_version

Every application event SHALL carry the application's `lock_version`
after the mutation it describes: 1 for `ApplicationWasAdded`, the
incremented value for updates, and the value the delete matched for
`ApplicationWasRemoved`.

#### Scenario: Add event carries initial lock_version

- **WHEN** an application is created
- **THEN** its `ApplicationWasAdded` event's `lock_version` is 1

#### Scenario: Update events carry the incremented lock_version

- **WHEN** an application whose `lock_version` is N is renamed, its
  description updated, or its enabled flag toggled
- **THEN** the stored event's `lock_version` is N + 1

#### Scenario: Removed event carries the matched lock_version

- **WHEN** an application whose `lock_version` is N is deleted
- **THEN** its `ApplicationWasRemoved` event's `lock_version` is N
