# Spec Delta

## Purpose

Persists domain events for the stream server admin portal: append-only,
seq-ordered storage in the portal database, written atomically with the
change each event describes, so future subscribers can reliably replay
what happened.

## ADDED Requirements

### Requirement: Stream record

The system SHALL maintain one `streams` row per event stream: a
surrogate integer `id` primary key, a unique non-empty `stream_id`
string, a `version` counter incremented by one per appended event, a
`created_at` timestamp, and a nullable `deleted_at`. Appending a
stream's first event SHALL create its row in the same transaction.

#### Scenario: Stream created on first append

- **WHEN** the first event for a stream is appended
- **THEN** a stream row exists for that `stream_id` with `version` 1

#### Scenario: Version counts appended events

- **WHEN** several events are appended to a stream, in one or more
  transactions
- **THEN** the stream's `version` increases by the number of appended
  events

#### Scenario: Streams are independent

- **WHEN** events are appended to different streams
- **THEN** each stream's `version` counts only its own events

### Requirement: Global `$all` stream

A `$all` stream SHALL exist whose `version` counts every appended
event, tracking the global event count. The `$all` name SHALL be
reserved and rejected as an event's `stream_id`.

#### Scenario: `$all` counts every event

- **WHEN** events are appended to any streams
- **THEN** the `$all` stream's `version` increases by the number of
  appended events and equals the total number of stored events

#### Scenario: `$all` is reserved

- **WHEN** an event is appended with `stream_id` `"$all"`
- **THEN** the append fails and no event is stored

### Requirement: Event record

The system SHALL persist each event in the portal database with: an
auto-increment integer `seq` primary key giving a global insertion
order, a `stream_id` identifying the stream the event belongs to, a
`version` giving the event's position within that stream as assigned by
the store, an `event_type` string, a `payload` binary, and an
`added_at` timestamp with microsecond precision. `stream_id` SHALL be
a non-empty string. The (`stream_id`, `version`) pair SHALL be unique.

#### Scenario: Appended event is persisted

- **WHEN** an event is appended
- **THEN** it is persisted with a generated `seq`, its `event_type`, the
  encoded `payload`, and an `added_at` timestamp, with `stream_id`
  taken from the event and `version` assigned as the next position on
  that stream

#### Scenario: Stream id is required

- **WHEN** an event is appended with a missing or empty `stream_id`
- **THEN** the append fails and no event is stored

#### Scenario: Version is a contiguous per-stream sequence

- **WHEN** events are appended to a stream
- **THEN** each stored event's `version` is its consecutive position on
  that stream, starting at 1

#### Scenario: Sequence gives a total order

- **WHEN** events are appended, including multiple events in one
  transaction
- **THEN** each later-appended event has a higher `seq` than every
  earlier one

#### Scenario: Duplicate stream position rejected

- **WHEN** an event row is stored whose (`stream_id`, `version`) pair
  already exists in the store
- **THEN** the write fails with a uniqueness error and no second event
  with that pair is stored

### Requirement: Event payload encoding

Each event SHALL be an Elixir struct. The stored `event_type` SHALL be
the event struct's module name as a string, and the `payload` SHALL be
the binary produced by encoding the event struct with
`:erlang.term_to_binary/1`. Decoding a stored `payload` SHALL reproduce
the original event struct.

#### Scenario: Event type is the module name

- **WHEN** an event struct is appended
- **THEN** the stored `event_type` equals the struct's module name
  rendered as a string

#### Scenario: Payload round-trips

- **WHEN** a stored event's `payload` is decoded
- **THEN** it yields a struct equal to the one that was appended

### Requirement: Transactional append

Appending events SHALL be expressible as part of a caller's database
transaction, so that an event, the change it describes, and the stream
version increment commit together or roll back together.

#### Scenario: Event and change commit together

- **WHEN** a record change and its event are placed in one database
  transaction that commits
- **THEN** both the record and the event are persisted

#### Scenario: Rollback discards the event

- **WHEN** a transaction containing a record change and its event fails
- **THEN** neither the record nor the event is persisted

#### Scenario: Multiple events in one append

- **WHEN** several events are appended in one transaction
- **THEN** all of them are persisted, each with its own `seq` and its
  own consecutive stream `version`

### Requirement: Event retrieval

The system SHALL return stored events filtered to a given set of event
type names and to `seq` greater than a given cursor, ordered by
ascending `seq`, with each `payload` decoded back into its event
struct.

#### Scenario: Filtering by event names

- **WHEN** events are fetched with a list of event type names
- **THEN** only events whose `event_type` is in the list are returned

#### Scenario: Filtering by seq cursor

- **WHEN** events are fetched with a `seq` cursor
- **THEN** only events with a `seq` greater than the cursor are returned

#### Scenario: Results are ordered by seq

- **WHEN** several stored events match a fetch
- **THEN** they are returned in ascending `seq` order

#### Scenario: Returned payload is the event struct

- **WHEN** a stored event is returned
- **THEN** its payload is decoded into the original event struct

#### Scenario: No matching events

- **WHEN** no stored event matches the given names and cursor
- **THEN** an empty list is returned
