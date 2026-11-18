# Application Connection Info Specification

## Purpose

Lets an application resolve requested country codes to the connection
info of an assigned stream server, chosen by current load, through the
stream server admin portal API.

## Requirements

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

### Requirement: Country codes parameter validation

The `country_codes` parameter SHALL be a list of 1 to 4 distinct
ISO 3166-1 alpha-2 codes, matched case-insensitively and normalized
to the stored lowercase `country` format; duplicates are allowed and
collapse only for the distinct-count check. Requests violating these
rules SHALL be rejected with 400.

#### Scenario: Missing country_codes parameter

- **WHEN** a request carries no `country_codes` parameter or a value
  that is not a list
- **THEN** the response is 400

#### Scenario: Too many distinct codes

- **WHEN** a request carries more than 4 distinct `country_codes`
- **THEN** the response is 400

#### Scenario: Empty country_codes list

- **WHEN** a request carries an empty `country_codes` list
- **THEN** the response is 400

#### Scenario: Malformed country code

- **WHEN** an entry's value is not an alpha-2 code, for example
  `"any"`, `"usa"`, or `"d1"`
- **THEN** the response is 400

#### Scenario: Case-insensitive code

- **WHEN** an entry's value is `"US"` or `"De"`
- **THEN** it is accepted and resolved as the normalized `"us"` /
  `"de"` code

### Requirement: Least-loaded server selection by country

For each requested `country_code`, the endpoint SHALL select the
stream server assigned to the authenticated application whose `country`
equals the code and whose `load` is lowest; when several servers tie
on the lowest load, any of them may be returned. Each requested code
produces one response entry, so repeated codes resolve identically.

#### Scenario: Least loaded chosen

- **WHEN** two assigned servers match a requested country with loads 40
  and 10
- **THEN** the server with load 10 is returned for that country

#### Scenario: Duplicate codes preserved

- **WHEN** the `country_codes` list contains `"us"` twice
- **THEN** the response contains two identical `"us"` entries

### Requirement: Unsatisfiable country fails the request

When no assigned stream server matches a requested `country_code`, the
endpoint SHALL reject the whole request with 422 and an error body
naming the country codes that could not be satisfied.

#### Scenario: No server for a country

- **WHEN** an assigned server exists for `"us"` but none for `"de"` and
  a request asks for both codes
- **THEN** the response is 422 and the error body names `"de"`

#### Scenario: No assigned servers at all

- **WHEN** the application has no assigned stream servers
- **THEN** the response is 422

### Requirement: Connection info response

On success the endpoint SHALL respond 200 with a JSON array carrying
one entry per requested `country_code`, in request order and
preserving duplicates. Each entry SHALL contain the normalized
(lowercase) `country_code`, `url` formed as `"https://" <> host`, and
`cert_hash` only when the selected server has one stored.

#### Scenario: Successful resolution

- **WHEN** every requested `country_code` resolves to an assigned server
- **THEN** the response is 200 with an array whose entries carry
  `country_code`, `url`, and `cert_hash` when present

#### Scenario: Server without a certificate hash

- **WHEN** the selected server has no `cert_hash` stored
- **THEN** that entry contains `country_code` and `url`, and no
  `cert_hash` key
