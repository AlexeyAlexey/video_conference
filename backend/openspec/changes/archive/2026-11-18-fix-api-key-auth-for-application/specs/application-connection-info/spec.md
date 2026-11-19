# Spec Delta

## MODIFIED Requirements

### Requirement: Disabled application rejected

Requests presenting an `aak_` credential whose owning application is
disabled SHALL be rejected with 401 during authentication, before the
endpoint runs — indistinguishable from an invalid credential.

#### Scenario: Disabled application

- **WHEN** an enabled `aak_` credential belongs to a disabled application
- **THEN** the request is rejected with 401
