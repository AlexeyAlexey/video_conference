# Spec Delta

## Purpose

Lets an application discover the country codes it can pass to the connection
info endpoint — the countries where it has at least one assigned stream
server — through the stream server admin portal API.

## ADDED Requirements

### Requirement: Available countries endpoint accepts application credentials only

The available countries endpoint SHALL accept only `aak_` credentials. A
request authenticated with an `ssak_` credential SHALL be rejected with
401, even when the credential itself is valid and enabled.

#### Scenario: Stream server credential rejected

- **WHEN** a request to the available countries endpoint presents a valid
  enabled `ssak_` secret
- **THEN** the request is rejected with 401

#### Scenario: Application credential accepted

- **WHEN** a request presents a valid enabled `aak_` secret
- **THEN** the request is authenticated as that credential's application

### Requirement: Disabled application rejected

Requests presenting an `aak_` credential whose owning application is
disabled SHALL be rejected with 401 during authentication, before the
endpoint runs — indistinguishable from an invalid credential.

#### Scenario: Disabled application

- **WHEN** an enabled `aak_` credential belongs to a disabled application
- **THEN** the request is rejected with 401

### Requirement: Response lists assigned-server countries

The endpoint SHALL respond `200` with a JSON array of the ISO alpha-2
`country` codes of the stream servers assigned to the authenticated
application — deduplicated, sorted alphabetically, and excluding servers
without a country. Server load SHALL NOT affect membership.

#### Scenario: Countries from assigned servers

- **WHEN** the application has assigned servers with countries `"de"`,
  `"us"`, and `"gb"`
- **THEN** the response is `200` with `["de", "gb", "us"]`

#### Scenario: Duplicate countries deduplicated

- **WHEN** two assigned servers share the country `"de"`
- **THEN** `"de"` appears exactly once in the response

#### Scenario: Server without a country excluded

- **WHEN** an assigned server has no `country` set
- **THEN** that server contributes no entry to the response

#### Scenario: Load does not filter countries

- **WHEN** the application has assigned servers for `"de"` with any
  load values
- **THEN** `"de"` is returned regardless of load

#### Scenario: No assigned servers

- **WHEN** the application has no assigned stream servers (or none with
  a country)
- **THEN** the response is `200` with `[]`
