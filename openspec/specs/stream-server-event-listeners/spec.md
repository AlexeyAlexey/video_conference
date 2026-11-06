# Stream Server Event Listeners Specification

## Purpose

Lets developers subscribe supervised listeners to the portal event
store: each listener declares which event types it handles and receives
them in `seq` order with durable, at-least-once delivery.

## Requirements

### Requirement: Listener declaration

The system SHALL let a developer define a listener module that declares
a unique non-empty `name`, a `description`, a non-empty list of
subscribed event types, and retry options, and that implements a
handler invoked once per matching stored event with that event's
decoded struct.

#### Scenario: Declared subscription is honored

- **WHEN** a listener declares a list of event types
- **THEN** only stored events whose `event_type` is in that list are
  delivered to its handler

#### Scenario: Handler receives the event struct

- **WHEN** a stored event is delivered to a listener
- **THEN** its handler is invoked with the decoded event struct, not the
  stored row

#### Scenario: Listener names are unique

- **WHEN** a listener is registered whose `name` matches an existing
  listener record
- **THEN** it resumes the existing record's progress rather than
  starting a duplicate subscription

### Requirement: Durable per-listener cursor

The system SHALL persist a `last_seen_seq` cursor per listener name,
plus the listener's `description` and `status`, in the portal database.
The cursor SHALL advance to an event's `seq` only after the handler
reports success for that event.

#### Scenario: Cursor advances only on success

- **WHEN** a listener's handler succeeds for an event
- **THEN** the listener's cursor is stored as that event's `seq` before
  the next event is delivered

#### Scenario: Failed event does not advance cursor

- **WHEN** a listener's handler fails for an event
- **THEN** the listener's cursor remains at the last successful event's
  `seq`

#### Scenario: Progress survives restart

- **WHEN** the application restarts after a listener processed events
- **THEN** the listener resumes from its persisted cursor and is not
  re-delivered events it already acknowledged

### Requirement: In-order at-least-once dispatch

The system SHALL deliver a listener's matching events strictly in
ascending `seq` order, one event at a time. Delivery SHALL be
at-least-once: an event whose handling succeeded but whose cursor
update was lost MAY be delivered again, so handlers must tolerate
re-delivery.

#### Scenario: Events delivered in seq order

- **WHEN** several stored events match a listener's subscription
- **THEN** they are delivered to its handler in ascending `seq` order,
  each after the previous one was acknowledged or failed

#### Scenario: Catch-up on start

- **WHEN** a listener starts with a cursor behind the newest matching
  event
- **THEN** all matching events after the cursor are delivered in order
  before newer ones

### Requirement: Configurable retries with backoff

The system SHALL retry a failed event a configurable number of times
per listener, waiting an exponentially increasing delay between
attempts. An exception raised by the handler SHALL be treated as a
failure, not a process crash.

#### Scenario: Retries with exponential backoff

- **WHEN** a handler fails for an event and the listener's retry budget
  is not exhausted
- **THEN** the event is retried after a delay that grows with each
  consecutive attempt

#### Scenario: Raised exception becomes a failure

- **WHEN** a handler raises while processing an event
- **THEN** the failure is recorded and handled by the retry policy
  exactly like an explicit error return

#### Scenario: Retry budget is per listener

- **WHEN** two listeners declare different retry counts
- **THEN** each retries its own failed events its declared number of
  times

### Requirement: Failed state is durable

The system SHALL mark a listener `failed` — recording the error that
halted it — when its retry budget is exhausted, and SHALL stop
delivering it events. A `failed` listener SHALL remain stopped,
including across application restarts, until it is explicitly resumed.

#### Scenario: Exhausted retries mark the listener failed

- **WHEN** a listener's handler has failed an event more than its
  configured retries
- **THEN** the listener's status becomes `failed`, the error is
  recorded, and no further events are delivered to it

#### Scenario: Failed listener stays down across restart

- **WHEN** the application restarts while a listener's status is
  `failed`
- **THEN** that listener is not started and no events are delivered to
  it

#### Scenario: Other listeners unaffected

- **WHEN** one listener is marked `failed`
- **THEN** other listeners continue receiving their subscribed events

### Requirement: Manual resume

The system SHALL provide a way to resume a `failed` listener by name.
Resuming SHALL clear the `failed` status and restart delivery from the
listener's persisted cursor, so the event that failed is retried first.

#### Scenario: Resume retries the failed event first

- **WHEN** a `failed` listener is resumed
- **THEN** its status becomes `ok` and delivery resumes starting with
  the first event after its persisted cursor — the event that failed

#### Scenario: Resume continues normal operation

- **WHEN** a resumed listener's handler succeeds on the retried event
- **THEN** its cursor advances and subsequent events are delivered
  normally
