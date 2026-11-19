# Spec Delta

## ADDED Requirements

### Requirement: Application API key record

The system SHALL persist each application API key with a UUID primary
key, a required non-unique `name`, an optional `description`, a unique
`prefix` holding the secret's `env_prefix <> "_" <> prefix_id` lookup
prefix, a secret stored only as a hash, a required `application_id`, an
`enabled` flag, a `lock_version`, and timestamps. The hashed secret
SHALL be unique within one application.

#### Scenario: API key belongs to an application

- **WHEN** an API key is created for an application
- **THEN** it is persisted with that application's id and is listed under that application

#### Scenario: Duplicate key name allowed

- **WHEN** an application already has an API key named "partner-integration"
- **THEN** creating another API key named "partner-integration" on the same application succeeds

### Requirement: Optimistic concurrency for application API keys

Every update of an application API key SHALL be guarded by the record's
`lock_version`: the write succeeds only when the persisted
`lock_version` still matches the version the caller loaded, and a
successful write increments it. A write attempted against a stale record
version SHALL fail and report the record as stale through the normal
error channel — it SHALL NOT raise an unhandled exception.

#### Scenario: Stale update rejected

- **WHEN** two admins load the same API key and both submit updates, the second write using the outdated `lock_version`
- **THEN** the second write fails with a stale-record error on the `lock_version` field and the first write's change is preserved

### Requirement: Application API keys page and required application filter

An authenticated portal admin SHALL be able to open a page at
`/stream-server-admin/api-keys` for managing application API keys. The
page SHALL offer a required application filter whose searchable options
are the application names. There SHALL be no option to select all
applications; until an application is chosen the page SHALL prompt the
admin to pick one and SHALL NOT list keys or offer adding a key. The
chosen application SHALL be reflected in the page URL.

#### Scenario: Prompt before an application is picked

- **WHEN** an admin opens the page with no application selected
- **THEN** the page shows a prompt to select an application, lists no keys, and the add action is unavailable

#### Scenario: Filtering keys by application

- **WHEN** an admin picks an application in the filter
- **THEN** the page lists that application's API keys and the URL carries the chosen application id

#### Scenario: Key prefix shown

- **WHEN** the page lists an application's API keys
- **THEN** each key row shows its `prefix` in an API KEY column with a copy affordance

#### Scenario: Searching filter options

- **WHEN** an admin types in the filter's search field
- **THEN** the application options are narrowed by the typed text

### Requirement: Application API key management

An authenticated portal admin SHALL be able to add an API key for the
filtered application through a modal whose form shows the application
read-only and accepts name, description, and enabled. The admin SHALL
rename a key, edit its description, and toggle its enabled flag through
per-field controls — there SHALL be no whole-row edit form and no
delete action. Validation errors SHALL be shown inline.

#### Scenario: Adding a key through the modal

- **WHEN** an admin with an application selected activates "Add API key" and submits a valid form
- **THEN** the key is created for the filtered application and the one-time secret is displayed

#### Scenario: Renaming a key

- **WHEN** an admin activates the rename control on a key row and saves a new name
- **THEN** the key's name is updated

#### Scenario: Editing a key's description

- **WHEN** an admin activates the description control on a key row and saves
- **THEN** the key's description is updated

#### Scenario: Toggling enabled

- **WHEN** an admin clicks a key's enabled checkbox
- **THEN** the enabled flag is persisted immediately to the opposite value

## MODIFIED Requirements

### Requirement: API key secret generation and one-time display

The system SHALL generate a random API key secret in the form
`env_prefix <> "_" <> prefix_id <> "_" <> <random>` — where `env_prefix`
is `"aak"` ("application api key") and `prefix_id` is an independently
generated id — when an API key is created, and SHALL persist the
`env_prefix <> "_" <> prefix_id` portion as the key's `prefix`. The
plaintext secret SHALL be displayed to the admin exactly once,
immediately after creation, and SHALL NOT be retrievable or displayed
again afterwards.

#### Scenario: Secret shown once on creation

- **WHEN** a portal admin creates an API key
- **THEN** the generated plaintext secret is displayed once on screen with a copy-to-clipboard control so it can be copied

#### Scenario: Secret not shown afterwards

- **WHEN** a portal admin later views the API keys list or an existing API key
- **THEN** no plaintext secret is displayed anywhere

## REMOVED Requirements

### Requirement: API key records

**Reason**: Superseded by "Application API key record" — the record
gains `prefix` and `lock_version` and key names are no longer unique
within an application, so its scenarios no longer describe the behavior.
**Migration**: The `api_keys` table is renamed to `application_api_keys`
with `prefix` and `lock_version` backfilled; the new record requirement
governs.

### Requirement: API key management grouped by application

**Reason**: The grouped, all-applications page with route-driven forms
and per-row delete is replaced by a required-application-filter page
with modal add and per-field editing, mirroring the stream server API
keys page; revocation is now disable, not delete.
**Migration**: Covered by "Application API keys page and required
application filter" and "Application API key management".
