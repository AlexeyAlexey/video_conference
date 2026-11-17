# Spec Delta

## Purpose

Lets an application resolve each of its named streams to the connection
info of an assigned stream server, chosen by country and current load,
through the stream server admin portal API.

## ADDED Requirements

### Requirement: Connection info endpoint accepts application credentials only

The connection info endpoint SHALL accept only `aak_` credentials. A
request authenticated with an `ssak_` credential SHALL be rejected with
401, even when the credential itself is valid and enabled.

#### Scenario: Stream server credential rejected

- **WHEN** a request to the connection info endpoint presents a valid
  enabled `ssak_` secret
- **THEN** the request is rejected with 401

#### Scenario: Application credential accepted

- **WHEN** a request presents a valid enabled `aak_` secret
- **THEN** the request is authenticated as that credential's application

### Requirement: Disabled application rejected

The endpoint SHALL reject requests whose authenticated application is
disabled with 404, indistinguishable from a missing application.

#### Scenario: Disabled application

- **WHEN** an enabled `aak_` credential belongs to a disabled application
- **THEN** the request is rejected with 404

### Requirement: Streams parameter validation

The `streams` parameter SHALL be a list of 1 to 4 entries. Each entry
SHALL have a `name` (a non-empty string of at most 20 characters) and a
`country_code` that is either the reserved value `"any"` or a
lowercase ISO 3166-1 alpha-2 code, matching the stored `country`
format. Requests violating these rules SHALL be rejected with 400.

#### Scenario: Missing streams parameter

- **WHEN** a request carries no `streams` parameter or a value that is
  not a list
- **THEN** the response is 400

#### Scenario: Too many streams

- **WHEN** a request carries more than 4 `streams` entries
- **THEN** the response is 400

#### Scenario: Empty streams list

- **WHEN** a request carries an empty `streams` list
- **THEN** the response is 400

#### Scenario: Invalid stream entry

- **WHEN** an entry lacks `name` or `country_code`, or `name` is empty
  or longer than 20 characters
- **THEN** the response is 400

#### Scenario: Malformed country code

- **WHEN** an entry's `country_code` is not `"any"` and not a
  lowercase ISO alpha-2 code, for example `"US"` or `"usa"`
- **THEN** the response is 400

### Requirement: Duplicate stream names deduplicated

When several `streams` entries share a `name`, the first occurrence
SHALL win and later entries with the same name SHALL be skipped.

#### Scenario: Duplicate names

- **WHEN** `streams` contains two entries named `"video"` with different
  country codes
- **THEN** the `"video"` key in the response reflects the first entry's
  country code and the second entry is ignored

### Requirement: Least-loaded server selection by country

For each requested `country_code`, the endpoint SHALL select the
stream server assigned to the authenticated application whose `country`
equals the code and whose `load` is lowest, breaking ties
deterministically. The reserved `country_code` `"any"` SHALL select
the least-loaded server among all servers assigned to the application,
regardless of country. Entries sharing a `country_code` SHALL resolve
to the same server.

#### Scenario: Least loaded chosen

- **WHEN** two assigned servers match a requested country with loads 40
  and 10
- **THEN** the server with load 10 is returned for that country

#### Scenario: Reserved any selects across countries

- **WHEN** an entry carries `country_code` `"any"` and the assigned
  servers span several countries
- **THEN** the least-loaded assigned server overall is returned for
  that entry

#### Scenario: Same country resolves identically

- **WHEN** two requested names carry the same `country_code`
- **THEN** both names map to connection info for the same server

### Requirement: Unsatisfiable country fails the request

When no assigned stream server matches a requested `country_code`, the
endpoint SHALL reject the whole request with 422 and an error body
naming the stream names that could not be satisfied.

#### Scenario: No server for a country

- **WHEN** an assigned server exists for `"us"` but none for `"de"` and
  a request asks for names in both countries
- **THEN** the response is 422 and the error body names the `"de"`
  stream names

#### Scenario: No assigned servers at all

- **WHEN** the application has no assigned stream servers and a request
  carries `country_code` `"any"`
- **THEN** the response is 422

### Requirement: Connection info response

On success the endpoint SHALL respond 200 with a JSON object keyed by
each unique requested `name`. Each value SHALL contain `url` formed as
`"https://" <> host`, and SHALL contain `cert_hash` only when the
selected server has one stored.

#### Scenario: Successful resolution

- **WHEN** every requested `country_code` resolves to an assigned server
- **THEN** the response is 200 with each unique `name` mapped to its
  server's `url` and `cert_hash` when present

#### Scenario: Server without a certificate hash

- **WHEN** the selected server has no `cert_hash` stored
- **THEN** that name's value contains `url` and no `cert_hash` key
