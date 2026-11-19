# Tasks

## 1. Lookup option

- [x] 1.1 Add an `:application_enabled` filter to
  `Applications.get_api_key_by_prefix` (becomes `/2` accepting the
  atom; when present, joins the parent application and requires
  `a.enabled`, returning `{:error, :not_found}` otherwise) and verify new tests in
  `applications_test.exs` pass: enabled app → `{:ok, key}`, disabled
  app → `{:error, :not_found}`, option absent → key returned regardless
  of app state. Update the docstring.

## 2. Auth plug

- [x] 2.1 Pass `:application_enabled` on the `"aak"` lookup in
  `ApiKeyAuth.fetch_credential/2` and verify a new
  `api_key_auth_test.exs` case passes: a valid secret for an enabled key
  on a disabled application halts with 401.
- [x] 2.2 Update `connection_info_controller_test.exs` "rejects a
  disabled application" to expect 401 instead of 404 and verify it
  passes. Update the controller moduledoc's `404` mention to reflect
  auth-layer rejection.

## 3. Verification

- [x] 3.1 Run `dotenv -e .env.test mix precommit` and fix any warnings
  or test failures.
