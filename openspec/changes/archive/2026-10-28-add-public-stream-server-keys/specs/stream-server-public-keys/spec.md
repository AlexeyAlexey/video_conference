# Spec Delta

## Purpose

Manages the application's per-stream-server public/private signing key pairs:
encrypted persistence, key generation, and the grouped admin UI. The public
key is shared with its stream server, which assigns a `public_key_id` used to
pick the key that verifies the application's signed JWTs.

## ADDED Requirements

### Requirement: Public stream server key record

The system SHALL persist each public stream server key with: a non-empty
`name`, an optional `public_key_id`, a `public_key`, an encrypted
`private_key`, a required `stream_server_id` association, a `disabled` flag
defaulting to false, and an optional `description`. `name` SHALL be unique
per stream server.

#### Scenario: Creating a key with required fields

- **WHEN** a public stream server key is created with a name, public key,
  private key, and a stream server
- **THEN** it is persisted with `disabled` false and no `public_key_id`

#### Scenario: Duplicate name on the same server rejected

- **WHEN** a key is created or renamed to a name already used by another key
  of the same stream server
- **THEN** the operation fails and the conflicting name is reported as taken

#### Scenario: Same name allowed on different servers

- **WHEN** a key is created with a name already used by a key of a different
  stream server
- **THEN** the key is persisted

#### Scenario: Stream server required

- **WHEN** a key is saved without a stream server
- **THEN** the operation fails and the missing stream server is reported

### Requirement: Private key encrypted at rest

The system SHALL encrypt `private_key` before persisting it, and decrypt it
only when needed for signing, using `SECRET_KEY_TO_ENCRYPT_PRIVATE_KEY` from
the environment. The persisted value SHALL NOT be the plaintext key.

#### Scenario: Stored value is ciphertext

- **WHEN** a public stream server key is saved with a private key
- **THEN** the persisted `private_key` differs from the submitted plaintext
  and decrypting it with the configured secret yields the original key

#### Scenario: Decryption without the secret fails

- **WHEN** the persisted `private_key` is decrypted with a different secret
- **THEN** decryption fails

### Requirement: Key pair generation

An admin SHALL be able to generate a new private/public key pair for a chosen
stream server and save it without a `public_key_id`, which can be filled in
later once the stream server assigns it.

#### Scenario: Generate and save a key pair

- **WHEN** an admin submits the generate form with a name and a stream server
- **THEN** a key is persisted with generated public and private key material
  and no `public_key_id`

#### Scenario: Public key id added later

- **WHEN** an admin edits a generated key and enters a `public_key_id`
- **THEN** the `public_key_id` is persisted

### Requirement: Public keys admin list

An authenticated admin SHALL be able to open a page at `/admin/stream-servers/keys` listing
public stream server keys grouped by stream server, with a description
explaining that public keys are shared with stream servers to verify the
application's signed JWTs. Unauthenticated visitors SHALL be redirected to
the admin sign-in page.

#### Scenario: List groups keys by stream server

- **WHEN** an authenticated admin opens `/admin/stream-servers/keys`
- **THEN** each stream server's keys are listed under that server with name,
  public key id, description, and disabled status

#### Scenario: Long descriptions are expandable

- **WHEN** a key's description exceeds the preview length
- **THEN** the list shows a truncated preview ending with `...`, and clicking
  it reveals the full description (and clicking again collapses it)

#### Scenario: No stream servers message

- **WHEN** an authenticated admin opens `/admin/stream-servers/keys` and no stream servers
  exist
- **THEN** a "No stream servers found" message is shown

#### Scenario: Unauthenticated access

- **WHEN** a visitor opens `/admin/stream-servers/keys` without an admin session
- **THEN** they are redirected to the admin sign-in page

### Requirement: Public keys admin management

An authenticated admin SHALL be able to add, generate, edit, and remove
public stream server keys from the admin page. Both the add and generate
forms SHALL offer a stream server dropdown. Validation errors SHALL be shown
inline.

#### Scenario: Add a key

- **WHEN** an admin submits the add form with a name, a stream server, a
  public key id, a public key, and a private key
- **THEN** the key is persisted and appears in the list

#### Scenario: Edit a key

- **WHEN** an admin submits the edit form for a key
- **THEN** the updated attributes are persisted and shown in the list

#### Scenario: Remove a key

- **WHEN** an admin confirms removal of a key
- **THEN** the key is deleted and disappears from the list

#### Scenario: Duplicate name shows error

- **WHEN** an admin submits a name already used by a key of the same stream
  server
- **THEN** the form shows an inline error and no duplicate is created

### Requirement: Private key secrecy in forms

The admin forms SHALL NOT display the decrypted private key. On edit, the
private key field SHALL render empty; submitting it blank keeps the stored
key, and submitting a new value replaces and re-encrypts it.

#### Scenario: Decrypted key never rendered

- **WHEN** an admin opens the edit form for a key
- **THEN** the private key field is empty and the decrypted value does not
  appear in the page

#### Scenario: Blank keeps stored key

- **WHEN** an admin saves the edit form with the private key field blank
- **THEN** the previously stored private key is unchanged

#### Scenario: New value replaces stored key

- **WHEN** an admin saves the edit form with a new private key value
- **THEN** the new key is encrypted and persisted in place of the old one

### Requirement: Sidebar navigation sub-item

The admin sidebar SHALL include a "Public keys" sub-item under "Stream
servers" that navigates to `/admin/stream-servers/keys`.

#### Scenario: Navigating via the sidebar

- **WHEN** an authenticated admin activates the "Public keys" sub-item under
  "Stream servers"
- **THEN** they are taken to the public keys page

### Requirement: Responsive public keys page

The public keys page SHALL be usable on mobile, tablet, and desktop
viewports. Data tables SHALL scroll horizontally inside their container
rather than overflowing the page.

#### Scenario: Grouped tables fit narrow screens

- **WHEN** the public keys list is viewed on a narrow viewport
- **THEN** the page does not overflow horizontally and each table scrolls
  inside its container
