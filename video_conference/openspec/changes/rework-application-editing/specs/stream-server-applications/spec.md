# Spec Delta

## ADDED Requirements

### Requirement: Optimistic concurrency for portal applications

Every update or delete of a portal application SHALL be guarded by
the record's `lock_version`: the write succeeds only when the persisted
`lock_version` still matches the version the caller loaded, and a
successful write increments it. A write attempted against a stale
record version SHALL fail and report the record as stale through the
normal error channel — it SHALL NOT raise an unhandled exception.

#### Scenario: Successful update increments lock version

- **WHEN** a portal application is renamed, has its description edited,
  or has its enabled flag toggled
- **THEN** its persisted `lock_version` increases by one

#### Scenario: Stale update is rejected

- **WHEN** an application is updated using a copy loaded before another
  update already committed
- **THEN** the operation fails reporting the record as stale and the
  persisted values are unchanged

#### Scenario: Stale delete is rejected

- **WHEN** an application is deleted using a copy loaded before another
  update already committed
- **THEN** the operation fails reporting the record as stale and the
  application remains persisted

## MODIFIED Requirements

### Requirement: Application records

Each application SHALL have a UUID primary key, a name, an optional
description, an enabled flag, a `lock_version` integer defaulting to 1,
and timestamps. Application names SHALL be unique across all
applications.

#### Scenario: Create an application

- **WHEN** a portal admin submits a new application with a name and optional description
- **THEN** an application record with a generated UUID id, the enabled flag set to true, `lock_version` 1, and timestamps is persisted

#### Scenario: Duplicate application name rejected

- **WHEN** a portal admin submits an application whose name already exists
- **THEN** the application is not created and a uniqueness error is shown

#### Scenario: Blank application name rejected

- **WHEN** a portal admin submits an application without a name
- **THEN** the application is not created and a validation error is shown

### Requirement: Application management in the portal

Authenticated portal admins SHALL be able to list all applications and
to create, rename, edit the description of, enable/disable, and delete
applications from the portal. Name and description SHALL each be edited
through its own modal opened from the row, with validation errors shown
inline. The enabled flag SHALL be shown as a checkbox in the list and
toggling it SHALL persist the change immediately without any further
action.

#### Scenario: Applications list

- **WHEN** a portal admin opens the applications page
- **THEN** all applications are listed with their name, description, an enabled-state checkbox, and an action to delete

#### Scenario: Edit an application

- **WHEN** a portal admin opens an application's name or description edit modal, changes the value, and saves
- **THEN** only that field's stored value is updated, and a duplicate name is rejected with an inline validation error

#### Scenario: Disable an application

- **WHEN** a portal admin unchecks the enabled checkbox of an enabled application
- **THEN** the application's enabled flag becomes false while its API keys remain stored

#### Scenario: Enable an application

- **WHEN** a portal admin checks the enabled checkbox of a disabled application
- **THEN** the application's enabled flag becomes true

#### Scenario: Delete an application

- **WHEN** a portal admin deletes an application
- **THEN** the application and all of its API keys are removed
