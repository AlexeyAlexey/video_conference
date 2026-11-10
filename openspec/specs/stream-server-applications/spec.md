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

### Requirement: API key records

Each API key SHALL have a UUID primary key, a name, an optional
description, a secret stored only as a hash, a required reference to its
application, an enabled flag, and timestamps. Within one application, API
key names SHALL be unique and API key secrets SHALL be unique.

#### Scenario: API key belongs to an application

- **WHEN** an API key is created for an application
- **THEN** it is persisted with that application's id and is listed under that application

#### Scenario: Duplicate key name within an application rejected

- **WHEN** a portal admin creates an API key whose name already exists on the same application
- **THEN** the key is not created and a uniqueness error is shown

#### Scenario: Same key name allowed on different applications

- **WHEN** a portal admin creates an API key whose name exists only on a different application
- **THEN** the key is created

### Requirement: API key secret generation and one-time display

The system SHALL generate a random API key secret when an API key is
created. The plaintext secret SHALL be displayed to the admin exactly
once, immediately after creation, and SHALL NOT be retrievable or
displayed again afterwards.

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

### Requirement: API key management grouped by application

Authenticated portal admins SHALL manage API keys from an API keys page
where keys are grouped by their application. For each key the admin SHALL
be able to create, edit name/description/enabled, and delete it.

#### Scenario: Keys grouped by application

- **WHEN** a portal admin opens the API keys page
- **THEN** API keys are presented grouped under their application

#### Scenario: Create an API key

- **WHEN** a portal admin creates an API key for a chosen application with a name and optional description
- **THEN** the key is persisted, the plaintext secret is displayed once, and the key appears under that application

#### Scenario: Edit an API key

- **WHEN** a portal admin updates an API key's name, description, or enabled flag
- **THEN** the record reflects the new values without changing the stored secret hash

#### Scenario: Delete an API key

- **WHEN** a portal admin deletes an API key
- **THEN** the key record is removed and no longer listed

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
