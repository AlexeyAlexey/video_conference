# Stream Server Applications Specification

## Purpose

Manages third-party applications that integrate with the stream server
and the API keys that authenticate them, so the portal can issue,
organize, enable, and revoke credentials for the stream-server REST API.

## Requirements

### Requirement: Application records

Each application SHALL have a UUID primary key, a name, an optional
description, an enabled flag, and timestamps. Application names SHALL be
unique across all applications.

#### Scenario: Create an application

- **WHEN** a portal admin submits a new application with a name and optional description
- **THEN** an application record with a generated UUID id, the enabled flag set to true, and timestamps is persisted

#### Scenario: Duplicate application name rejected

- **WHEN** a portal admin submits an application whose name already exists
- **THEN** the application is not created and a uniqueness error is shown

#### Scenario: Blank application name rejected

- **WHEN** a portal admin submits an application without a name
- **THEN** the application is not created and a validation error is shown

### Requirement: Application management in the portal

Authenticated portal admins SHALL be able to list all applications and to
create, edit, enable/disable, and delete applications from the portal.

#### Scenario: Applications list

- **WHEN** a portal admin opens the applications page
- **THEN** all applications are listed with their name, enabled state, and actions to edit or delete

#### Scenario: Edit an application

- **WHEN** a portal admin updates an application's name, description, or enabled flag
- **THEN** the application record reflects the new values

#### Scenario: Disable an application

- **WHEN** a portal admin disables an enabled application
- **THEN** the application's enabled flag becomes false while its API keys remain stored

#### Scenario: Delete an application

- **WHEN** a portal admin deletes an application
- **THEN** the application and all of its API keys are removed

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

### Requirement: API key secrets stored hashed

API key secrets SHALL be persisted only as a bcrypt hash. The plaintext
secret SHALL NOT be stored in the database, in logs, or in any other
persistent form.

#### Scenario: Stored value is a hash

- **WHEN** an API key record is inspected in the database
- **THEN** the secret field contains a bcrypt hash, not the plaintext secret

#### Scenario: Plaintext is verifiable against the hash

- **WHEN** the displayed plaintext secret is checked against the stored hash
- **THEN** it verifies, and a different secret does not verify

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

### Requirement: Truncated descriptions in portal lists

Descriptions longer than 50 characters SHALL be truncated with an
ellipsis in the applications and API keys lists, and SHALL expand to the
full text when activated.

#### Scenario: Expand a truncated description

- **WHEN** a portal admin activates a truncated description in an applications or API keys list
- **THEN** the full description is displayed

### Requirement: Default application and API key seeded at deploy

The system SHALL seed a default application and a default API key through
a script that runs when the application is deployed. The default
application id SHALL come from the `DEFAULT_STREAM_SERVER_APP_ID`
environment variable and the default API key secret from
`DEFAULT_STREAM_SERVER_API_KEY`.

#### Scenario: Fresh deployment seeds defaults

- **WHEN** the deploy script runs against an empty portal database with `DEFAULT_STREAM_SERVER_APP_ID` and `DEFAULT_STREAM_SERVER_API_KEY` set
- **THEN** an application named "Default App" with the env-provided UUID and an API key named "Default API Key" whose hash verifies the env-provided secret exist

#### Scenario: Seeded descriptions warn about production use

- **WHEN** the seeded default application and API key are inspected
- **THEN** their descriptions state they are defaults that must be replaced for production

#### Scenario: Seeding is idempotent

- **WHEN** the deploy script runs against a portal database that already has the default application and API key
- **THEN** no duplicate records are created and no error occurs

### Requirement: Responsive applications and API keys UI

The applications and API keys pages SHALL render a usable layout across
mobile, tablet, and desktop viewport sizes.

#### Scenario: Mobile viewport

- **WHEN** a portal admin opens the applications or API keys page on a small viewport
- **THEN** all lists, forms, and actions are reachable and usable without horizontal scrolling

#### Scenario: Desktop viewport

- **WHEN** a portal admin opens the applications or API keys page on a desktop viewport
- **THEN** the layout renders correctly with content appropriately sized and aligned

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
