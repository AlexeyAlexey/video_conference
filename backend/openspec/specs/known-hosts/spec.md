# Known Hosts Specification

## Purpose

Maintains the directory of peer application instances ("known hosts") that
this host is aware of, including the host's own identity, and provides
administrators a UI in the admin portal to manage that directory.

## Requirements

### Requirement: Known host record

The system SHALL persist each known host with: a unique non-empty `name`,
an optional `name_alias` used as a display name, an optional `description`,
an optional `host` address string (ip, domain, or ip+port), a
`current_host` flag, an `enabled` flag, and an optional `settings` map
defaulting to an empty map.

#### Scenario: Creating a known host with required fields

- **WHEN** a known host is created with a unique name and no optional fields
- **THEN** it is persisted with `enabled` true, `current_host` false, and `settings` as an empty map

#### Scenario: Duplicate name rejected

- **WHEN** a known host is created or renamed to a name that already exists
- **THEN** the operation fails and the conflicting name is reported as taken

### Requirement: Single current host

The system SHALL guarantee exactly one known host is marked `current_host`. On a fresh deployment the migration seed SHALL create a current host row named `current host` that is enabled. No operation SHALL produce zero or more than one current host.

#### Scenario: Fresh deployment has current host

- **WHEN** the application database is migrated on an empty database
- **THEN** a known host named `current host` exists with `current_host` true and `enabled` true

#### Scenario: Second current host rejected

- **WHEN** a known host other than the current host is saved with `current_host` true
- **THEN** the operation fails and only one current host remains

### Requirement: Current host protection

The system SHALL refuse to delete or disable the current host. Editing the current host SHALL NOT be able to clear its `current_host` flag or set `enabled` to false.

#### Scenario: Current host cannot be removed

- **WHEN** an attempt is made to delete the known host marked `current_host`
- **THEN** the delete fails and the current host row remains

#### Scenario: Current host cannot be disabled

- **WHEN** an attempt is made to save the current host with `enabled` false
- **THEN** the save fails and the current host remains enabled

#### Scenario: Current host editable fields

- **WHEN** the current host's `name_alias`, `description`, or `host` is updated
- **THEN** the update succeeds and `current_host` and `enabled` remain true

### Requirement: Known hosts admin list

An authenticated admin SHALL be able to open a page at `/admin/known-hosts` listing every known host with its name, display alias, host, and status. The current host SHALL be visibly marked with a "Current" badge. Unauthenticated visitors SHALL be redirected to the admin sign-in page.

#### Scenario: List renders all hosts

- **WHEN** an authenticated admin opens `/admin/known-hosts`
- **THEN** every known host is listed with its name, alias, host, and enabled status

#### Scenario: Current host badge

- **WHEN** the list contains the current host
- **THEN** its row shows a "Current" badge

#### Scenario: Unauthenticated access

- **WHEN** a visitor opens `/admin/known-hosts` without an admin session
- **THEN** they are redirected to the admin sign-in page

### Requirement: Known hosts admin management

An authenticated admin SHALL be able to add, edit, and remove known hosts from the admin list page. The UI SHALL NOT offer disable or remove actions for the current host, and SHALL show validation errors inline.

#### Scenario: Add a known host

- **WHEN** an admin submits the add form with a unique name and optional fields
- **THEN** the new host is persisted and appears in the list

#### Scenario: Duplicate name shows error

- **WHEN** an admin submits a name that already exists
- **THEN** the form shows an inline error and no duplicate is created

#### Scenario: Edit a known host

- **WHEN** an admin submits the edit form for a non-current host
- **THEN** the updated attributes are persisted and shown in the list

#### Scenario: Remove a known host

- **WHEN** an admin confirms removal of a non-current host
- **THEN** the host is deleted and disappears from the list

#### Scenario: No destructive actions on current host

- **WHEN** the list is rendered
- **THEN** the current host row offers no disable or remove control

### Requirement: Sidebar navigation entry

The admin sidebar SHALL include a "Known hosts" item that navigates to `/admin/known-hosts`.

#### Scenario: Navigating via the sidebar

- **WHEN** an authenticated admin activates the "Known hosts" sidebar item
- **THEN** they are taken to the known hosts page
