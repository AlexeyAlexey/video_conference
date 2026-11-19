# Spec Delta

## MODIFIED Requirements

### Requirement: API key authentication via X-API-Key

Requests to the stream server API SHALL present an API key secret in the
`X-API-Key` header. The system SHALL dispatch on the secret's
`env_prefix` to select the credential table (`"ssak"` for stream server
API keys, `"aak"` for application API keys), look the credential up by
its stored `prefix`, verify the presented secret against the stored
hash, and require the credential to be enabled. For an `aak_`
credential the lookup SHALL also require the credential's owning
application to be enabled; a key on a disabled application SHALL be
indistinguishable from an unknown prefix. Requests failing any of these
steps SHALL be rejected with 401 and a JSON error body.

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
