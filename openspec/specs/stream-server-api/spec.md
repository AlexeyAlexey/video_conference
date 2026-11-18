# Stream Server Api Specification

## Purpose

Exposes a REST API on the stream server admin portal for remote stream
servers, authenticated by `ssak_` API keys, starting with resolution of
an application's public key by its key id.

## Requirements

### Requirement: API key authentication via X-API-Key

Requests to the stream server API SHALL present an API key secret in the
`X-API-Key` header. The system SHALL dispatch on the secret's
`env_prefix` to select the credential table (`"ssak"` for stream server
API keys, `"aak"` for application API keys), look the credential up by
its stored `prefix`, verify the presented secret against the stored
hash, and require the credential to be enabled. For an `aak_`
credential the lookup SHALL also require the credential's owning
application to be enabled; a key on a disabled application SHALL be
indistinguishable from an unknown prefix. Requests failing any of
these steps SHALL be rejected with 401 and a JSON error body.

#### Scenario: Valid enabled credential authenticates

- **WHEN** a request presents an `X-API-Key` secret whose prefix matches
  an enabled stream server API key and whose secret verifies
- **THEN** the request is authenticated as that credential's stream
  server

#### Scenario: Missing or malformed header

- **WHEN** a request has no `X-API-Key` header or a secret that does not
  match the `env_prefix <> "_" <> prefix_id <> "_" <> random` structure
- **THEN** the request is rejected with 401

#### Scenario: Unknown prefix rejected

- **WHEN** a request presents a secret whose `env_prefix <> "_" <>
  prefix_id` prefix matches no stored credential
- **THEN** the request is rejected with 401

#### Scenario: Wrong secret rejected

- **WHEN** a request presents a secret whose prefix matches a stored
  credential but whose secret fails hash verification
- **THEN** the request is rejected with 401

#### Scenario: Disabled credential rejected

- **WHEN** a request presents a valid secret for a credential whose
  `enabled` flag is false
- **THEN** the request is rejected with 401

#### Scenario: Application credential of disabled application rejected

- **WHEN** a request presents a valid secret for an enabled `aak_`
  credential whose owning application is disabled
- **THEN** the request is rejected with 401, indistinguishable from an
  unknown prefix

#### Scenario: Unrecognized env_prefix rejected

- **WHEN** a request presents a secret with an `env_prefix` other than
  `ssak` or `aak`
- **THEN** the request is rejected with 401

### Requirement: Public key endpoint accepts stream server credentials only

The public key endpoint SHALL accept only `ssak_` credentials. A request
authenticated with an `aak_` credential SHALL be rejected with 401, even
when the credential itself is valid and enabled.

#### Scenario: Application credential rejected

- **WHEN** a request to the public key endpoint presents a valid enabled
  `aak_` secret
- **THEN** the request is rejected with 401

### Requirement: Public key resolution by application and key id

Given `application_id` and `public_key_id` params, the endpoint SHALL
return the stored public key material for the enabled
`StreamServerPublicKey` record whose id equals `public_key_id` and whose
`application_id` equals `application_id`, as a JSON body containing
`application_id`, `public_key_id`, and `key`. Missing or malformed
params SHALL be rejected with 400.

#### Scenario: Key returned

- **WHEN** an authorized stream server requests a key for an assigned
  application and an enabled key id belonging to that application
- **THEN** the response is 200 with `application_id`, `public_key_id`,
  and the stored `key` material

#### Scenario: Malformed params rejected

- **WHEN** `application_id` or `public_key_id` is missing or not a UUID
- **THEN** the response is 400

### Requirement: Assignment-scoped authorization

The endpoint SHALL serve a key only when the authenticated stream server
is assigned to the requested application via
`application_stream_servers`. An authenticated server that is not
assigned SHALL be rejected with 403.

#### Scenario: Unassigned application forbidden

- **WHEN** an authenticated stream server requests a key for an
  application it is not assigned to
- **THEN** the response is 403

#### Scenario: Assigned application allowed

- **WHEN** an authenticated stream server requests a key for an
  application it is assigned to
- **THEN** the request proceeds to key resolution

### Requirement: Not-found semantics

The endpoint SHALL respond 404 when the requested application does not
exist or is disabled, or when the requested key does not exist, does not
belong to the application, or is disabled. Disabled resources SHALL be
indistinguishable from missing ones.

#### Scenario: Unknown key id

- **WHEN** an authorized request names a `public_key_id` that does not
  exist
- **THEN** the response is 404

#### Scenario: Key of another application

- **WHEN** an authorized request names a `public_key_id` belonging to a
  different application than `application_id`
- **THEN** the response is 404

#### Scenario: Disabled key or application

- **WHEN** an authorized request names a disabled key or a disabled
  application
- **THEN** the response is 404
