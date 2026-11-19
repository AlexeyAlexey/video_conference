# Design

## Context

`ApiKeyAuth` resolves a presented `aak_` secret via
`Applications.get_api_key_by_prefix/1`, which matches only on the
stored `prefix` column. The plug then checks the key's own `enabled`
flag and verifies the bcrypt hash; a prefix miss takes a
`Bcrypt.no_user_verify()` detour so misses and hits have comparable
timing. Whether the key's parent `Application` is enabled is checked
later, per endpoint, by `Applications.authenticated_application/1`
(which additionally resolves the key to its `%Application{}`). See
proposal.md for why that layering is the problem.

`stream_servers` has no `enabled` column, so no symmetric filter is
needed for the `ssak` lookup.

## Goals / Non-Goals

**Goals:**

- A disabled application's `aak_` keys fail authentication at the plug
  with 401, uniform with an unknown prefix in response and timing.
- The parent-enabled check is opt-in on the lookup so non-auth callers
  keep today's semantics.
- One query per authenticated request — no extra round-trip.

**Non-Goals:**

- No `:stream_server_enabled` filter for `ssak` lookups (no such column;
  can be added later if stream servers gain `enabled`).
- No change to `Applications.authenticated_application/1` — its
  `enabled: true` filter becomes unreachable but stays as
  defense-in-depth.
- No preloading of `key.application` onto the credential; the existing
  second query in `authenticated_application/1` remains.

## Decisions

### Filter atom on `get_api_key_by_prefix` over other placements

`get_api_key_by_prefix(prefix, :application_enabled)` performs a join on
the parent application with an `a.enabled` predicate. The second
parameter is a bare atom rather than a keyword list: only one filter
exists, and if more are ever needed the parameter can widen to a list
of atoms without changing the atom call site. Alternatives considered:

- **Check in the plug after fetch** — requires loading the association
  (second query or a preload) and adds a new rejection branch to
  `authenticate/2`. Works, but duplicates the lookup's job and keeps
  the "fetch then re-check" layering this change removes.
- **Preload `:application` and check `key.application.enabled`** —
  collapses `authenticated_application/1`'s second query too, but
  changes the credential's loaded-associations contract for all
  callers and was explicitly ruled out of scope.
- **Separate function (e.g. `get_enabled_api_key_by_prefix`)** —
  equivalent; a filter parameter was chosen because it keeps one entry
  point and composes if more filters are ever needed.

The filter only alters the query when present;
`get_api_key_by_prefix/1` without a filter behaves exactly as today
(the `:application_enabled` branch applies the join conditionally,
keeping the plain `Repo.get_by` path for existing callers).

### Disabled application returns `{:error, :not_found}`

The join makes a disabled-app key indistinguishable from a missing key
at the return value, so the plug's existing `not_found` branch applies:
`Bcrypt.no_user_verify()` keeps timing uniform and the caller gets the
same 401 as for a nonexistent prefix. No new error variant is
introduced — distinguishing "disabled app" from "no such key"
internally would add a code path no consumer uses.

### 401 at auth replaces 404 at endpoint

The endpoint-level 404 (spec: `application-connection-info`, "Disabled
application rejected") becomes unreachable and is respecified as 401.
401 is the more conservative contract: it reveals less (valid-key /
disabled-app is indistinguishable from a garbage secret) and removes
the need for every `aak_` endpoint to re-check parent state.

## Risks / Trade-offs

- [Clients handling 404 for disabled applications break] → called out
  as BREAKING in the proposal and in the respecified requirement;
  acceptable because the API is consumed by a small set of first-party
  applications.
- [Join adds a row read to every `aak_` authentication] → one indexed
  join per request; cheaper than the previous worst case (fetch + a
  second `applications` query at the endpoint).
- [`authenticated_application/1` retains a now-redundant enabled
  check] → accepted deliberately: costs one indexed query and keeps
  the endpoint safe if it is ever called with a credential produced
  outside `ApiKeyAuth`.

Note: `ApiKeyAuth` is the only production caller of
`get_api_key_by_prefix`, so `/1` remains only as the unfiltered form
for tests and future non-auth callers.
