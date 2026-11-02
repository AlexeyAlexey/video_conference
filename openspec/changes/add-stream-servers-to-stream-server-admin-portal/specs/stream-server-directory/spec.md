# Spec Delta

## Purpose

Maintains the stream server admin portal's registry of physical stream
servers available to carry video, audio, and event streams, and records
which applications each server is assigned to.

## ADDED Requirements

### Requirement: Portal stream server record

The system SHALL persist each portal stream server with a UUID primary
key, a unique non-empty `name`, an optional `description`, a `host`
address string (ip, domain, or ip:port), an optional `country` location
code, an optional `settings` map defaulting to an empty map, and an
optional `cert_hash`.

#### Scenario: Creating a stream server

- **WHEN** a portal admin creates a stream server with a name and host
- **THEN** the server is persisted with a generated UUID and an empty
  settings map

#### Scenario: Duplicate name rejected

- **WHEN** a portal admin creates or edits a stream server using a name
  that another portal stream server already has
- **THEN** the change is rejected with a validation error

### Requirement: Portal stream server country location

The system SHALL store an optional `country` on each portal stream
server as an ISO 3166-1 alpha-2 code. The admin form SHALL offer the
country as a searchable choice of flag + country-name options including
an empty choice, and the list SHALL display each server's flag.

#### Scenario: Picking a country

- **WHEN** a portal admin opens the country selector in the stream
  server form
- **THEN** a searchable list of flag + country-name options is shown
  including an empty choice

#### Scenario: Flag shown in the list

- **WHEN** the stream servers list renders a server with a country
- **THEN** that country's flag is displayed for the server

### Requirement: Portal stream server certificate hash

The system SHALL store the stream server's TLS certificate hash in a
`cert_hash` column, and SHALL allow it to be set or cleared when the
server is created or edited, for servers that use a self-signed
certificate.

#### Scenario: Setting a certificate hash

- **WHEN** a portal admin saves a stream server with a certificate hash
- **THEN** the hash is persisted on the server's `cert_hash` column

#### Scenario: Clearing a certificate hash

- **WHEN** a portal admin edits a stream server and saves it with a
  blank certificate hash
- **THEN** the stored `cert_hash` is cleared

### Requirement: Portal stream servers list

An authenticated portal admin SHALL be able to open a page at
`/stream-server-admin/stream-servers` listing every portal stream
server with its name, host, country flag, certificate hash presence, and
assigned applications. Unauthenticated visitors SHALL be redirected to
the portal sign-in page.

#### Scenario: Viewing the stream servers list

- **WHEN** an authenticated portal admin opens
  `/stream-server-admin/stream-servers`
- **THEN** every portal stream server is shown with its name, host,
  country flag, whether a certificate hash is set, and its assigned
  applications

#### Scenario: Unauthenticated visitor redirected

- **WHEN** a visitor without a portal admin session opens
  `/stream-server-admin/stream-servers`
- **THEN** they are redirected to the portal sign-in page

### Requirement: Portal stream server management

An authenticated portal admin SHALL be able to add, edit, and remove
portal stream servers from the list page, including setting the
certificate hash and the country location. Validation errors SHALL be
shown inline.

#### Scenario: Adding a stream server

- **WHEN** a portal admin submits the new stream server form with valid
  data
- **THEN** the server is created and shown in the list

#### Scenario: Editing a stream server

- **WHEN** a portal admin submits the edit form for a stream server
- **THEN** the server's stored fields are updated

#### Scenario: Removing a stream server

- **WHEN** a portal admin removes a stream server
- **THEN** the server and its application assignments are deleted

#### Scenario: Invalid form shows errors

- **WHEN** a portal admin submits the stream server form with invalid
  data
- **THEN** the form is re-rendered with inline validation errors

### Requirement: Application assignment

The system SHALL record a many-to-many assignment between portal stream
servers and applications. An authenticated portal admin SHALL be able to
assign and unassign one or more applications to a stream server from a
dedicated assign view, and SHALL see each server's assigned applications
in the list. Deleting an application or a stream server SHALL remove its
assignments.

#### Scenario: Assigning applications

- **WHEN** a portal admin selects one or more applications in a server's
  assign view and saves
- **THEN** the server is assigned to exactly those applications

#### Scenario: Unassigning an application

- **WHEN** a portal admin deselects an application in a server's assign
  view and saves
- **THEN** that assignment is removed

#### Scenario: Same server in multiple applications

- **WHEN** a portal admin assigns the same stream server to several
  applications
- **THEN** the server appears as assigned in each of those applications

#### Scenario: Assigned applications shown in list

- **WHEN** the stream servers list renders a server with assigned
  applications
- **THEN** the names of its assigned applications are displayed

#### Scenario: Deleted application removes assignment

- **WHEN** an application assigned to stream servers is deleted
- **THEN** its assignments are removed and the servers remain

### Requirement: Filter stream servers by application

The portal stream servers list SHALL offer a filter limiting the list to
servers assigned to a chosen application, including an option for all
servers and an option for servers with no assigned application.

#### Scenario: Filtering by an application

- **WHEN** a portal admin picks an application in the filter
- **THEN** only stream servers assigned to that application are listed

#### Scenario: Filtering to unassigned servers

- **WHEN** a portal admin picks the unassigned option in the filter
- **THEN** only stream servers with no assigned application are listed

#### Scenario: Clearing the filter

- **WHEN** a portal admin picks the all-servers option in the filter
- **THEN** every portal stream server is listed again

### Requirement: Responsive stream servers page

The portal stream servers page SHALL be usable on mobile, tablet, and
desktop viewports. Its data table SHALL scroll horizontally inside its
container rather than overflowing the page.

#### Scenario: Mobile viewport

- **WHEN** a portal admin opens the stream servers page on a narrow
  viewport
- **THEN** the page layout adapts and the table scrolls horizontally
  within its container

#### Scenario: Assign view on mobile

- **WHEN** a portal admin opens a server's assign view on a narrow
  viewport
- **THEN** the assign view remains usable and applications can be
  selected
