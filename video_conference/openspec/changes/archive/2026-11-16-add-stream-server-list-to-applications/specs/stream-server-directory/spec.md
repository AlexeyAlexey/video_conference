# Spec Delta

## ADDED Requirements

### Requirement: Application stream servers page and required application filter

An authenticated portal admin SHALL be able to open a page at
`/stream-server-admin/applications/stream-servers` listing the stream
servers assigned to an application. The page SHALL offer a required
searchable application filter; until an application is chosen the page
SHALL prompt the admin to pick one and SHALL NOT list servers. The
chosen application SHALL be reflected in the page URL.

#### Scenario: Prompt before an application is picked

- **WHEN** an admin opens the page with no application selected
- **THEN** the page shows a prompt to select an application and lists no
  stream servers

#### Scenario: Listing an application's stream servers

- **WHEN** an admin picks an application in the filter
- **THEN** the page lists every stream server assigned to that
  application and the URL carries the chosen application id

#### Scenario: Server details shown

- **WHEN** the page lists an application's stream servers
- **THEN** each row shows the server's name, host, country flag,
  description, and certificate hash with a copy affordance

#### Scenario: Read-only list

- **WHEN** the page lists an application's stream servers
- **THEN** no action to add, edit, remove, assign, or unassign a stream
  server is offered

#### Scenario: Application with no assigned servers

- **WHEN** an admin picks an application that has no stream servers
  assigned
- **THEN** the page shows an empty list instead of server rows

#### Scenario: Searching filter options

- **WHEN** an admin types in the filter's search field
- **THEN** the application options are narrowed by the typed text

#### Scenario: Unauthenticated visitor redirected

- **WHEN** a visitor without a portal admin session opens the page
- **THEN** they are redirected to the portal sign-in page
