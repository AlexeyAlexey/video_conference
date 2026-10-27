# Stream Servers Specification

## Purpose

Maintains the directory of HTTP/3 stream servers — self-hosted and
third-party — that can carry video, audio, and event streams for
participants.

## Requirements

### Requirement: Stream server record

The system SHALL persist each stream server with: a unique non-empty
`name`, an optional `description`, a `host` address string (ip, domain,
or ip:port), an optional `country` location code, an optional `settings`
map defaulting to an empty map, and a `third_party` flag.

#### Scenario: Creating a stream server with required fields

- **WHEN** a stream server is created with a unique name and no optional fields
- **THEN** it is persisted with no `country`, `third_party` false, and `settings` as an empty map

#### Scenario: Duplicate name rejected

- **WHEN** a stream server is created or renamed to a name that already exists
- **THEN** the operation fails and the conflicting name is reported as taken

### Requirement: Stream server country location

The system SHALL store an optional `country` on each stream server as an
ISO 3166-1 alpha-2 code. The admin form SHALL offer the country as a
searchable choice of flag + country-name options including an empty
choice, and the list SHALL display each server's flag.

#### Scenario: Country chosen from the flag list

- **WHEN** an admin selects a country flag in the stream server form and saves
- **THEN** the server's `country` is persisted as that country's alpha-2 code and its flag appears in the list

#### Scenario: Searching the country list

- **WHEN** an admin types in the country search field in the stream server form
- **THEN** only countries matching the search text are offered for selection

#### Scenario: Empty country allowed

- **WHEN** an admin saves a stream server with the empty country choice
- **THEN** the server is persisted with no `country`

#### Scenario: Invalid country rejected

- **WHEN** a stream server is saved with a country value that is not a supported ISO alpha-2 code
- **THEN** the operation fails and the invalid value is reported

### Requirement: Certificate hash in settings

The system SHALL store the stream server's TLS certificate hash under
`settings.cert_hash`, and SHALL allow it to be set or cleared when the
server is created or edited.

#### Scenario: Setting the certificate hash

- **WHEN** a stream server is saved with a certificate hash value
- **THEN** `settings.cert_hash` contains that value

#### Scenario: Clearing the certificate hash

- **WHEN** a stream server is saved with the certificate hash emptied
- **THEN** `settings.cert_hash` is absent or empty

### Requirement: Stream servers admin list

An authenticated admin SHALL be able to open a page at
`/admin/stream-servers` listing every stream server with its name, host,
country flag, and third-party flag. Unauthenticated
visitors SHALL be redirected to the admin sign-in page.

#### Scenario: List renders all servers

- **WHEN** an authenticated admin opens `/admin/stream-servers`
- **THEN** every stream server is listed with its name, host, country flag, and third-party flag

#### Scenario: Unauthenticated access

- **WHEN** a visitor opens `/admin/stream-servers` without an admin session
- **THEN** they are redirected to the admin sign-in page

### Requirement: Stream servers admin management

An authenticated admin SHALL be able to add, edit, and remove stream
servers from the admin list page, including setting the certificate
hash, the country location, and the third-party flag.
Validation errors SHALL be shown inline.

#### Scenario: Add a stream server

- **WHEN** an admin submits the add form with a unique name and optional fields
- **THEN** the new server is persisted and appears in the list

#### Scenario: Duplicate name shows error

- **WHEN** an admin submits a name that already exists
- **THEN** the form shows an inline error and no duplicate is created

#### Scenario: Edit a stream server

- **WHEN** an admin submits the edit form for a stream server
- **THEN** the updated attributes are persisted and shown in the list

#### Scenario: Remove a stream server

- **WHEN** an admin confirms removal of a stream server
- **THEN** the server is deleted and disappears from the list

### Requirement: Sidebar navigation entry

The admin sidebar SHALL include a "Stream servers" item that navigates
to `/admin/stream-servers`.

#### Scenario: Navigating via the sidebar

- **WHEN** an authenticated admin activates the "Stream servers" sidebar item
- **THEN** they are taken to the stream servers page

### Requirement: Responsive admin pages

The admin pages SHALL be usable on mobile, tablet, and desktop
viewports. Data tables SHALL scroll horizontally inside their container
rather than overflowing the page. The navigation sidebar SHALL behave as
a dismissible drawer on viewports below the `lg` breakpoint and as a
permanent sidebar at `lg` and above.

#### Scenario: Sidebar is a closed drawer on small screens

- **WHEN** an authenticated admin opens an admin page on a small viewport
- **THEN** the sidebar is hidden by default and can be opened and dismissed with the toggle or its backdrop

#### Scenario: Table fits narrow screens

- **WHEN** the stream servers list is viewed on a narrow viewport
- **THEN** the page does not overflow horizontally and the table scrolls inside its container
