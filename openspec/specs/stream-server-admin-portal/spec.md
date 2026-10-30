# Stream Server Admin Portal Specification

## Purpose

Provides an isolated administrative web portal for stream-server
management, with its own database, repository, and email/password
authentication, so stream-server administration can evolve independently
of the application and its admin portal.

## Requirements

### Requirement: Portal data in dedicated database

Portal data SHALL be persisted in a dedicated SQLite database through a
dedicated Ecto repository, with migrations in a portal-specific
migrations directory, so the portal's data is physically isolated from
the main application database.

#### Scenario: Portal records use the dedicated database

- **WHEN** a portal admin or token record is created or queried
- **THEN** it is read from and written to the portal database, not the main application database

#### Scenario: Portal migrations live apart from app migrations

- **WHEN** portal migrations run
- **THEN** they are applied to the portal database from the portal migrations directory, separately from the migrations under `priv/repo/migrations`

#### Scenario: Portal tables absent from main database

- **WHEN** the main application database is created and migrated
- **THEN** it contains no portal tables

### Requirement: Portal accessible at its own mount path

The portal SHALL be served under the `/stream-server-admin` path prefix, with the sign-in page at `/stream-server-admin/log-in`, independent of the `/admin` admin portal.

#### Scenario: Portal root requires sign-in

- **WHEN** an unauthenticated visitor requests `/stream-server-admin`
- **THEN** they are redirected to `/stream-server-admin/log-in`

#### Scenario: Portal routes do not collide with admin routes

- **WHEN** a visitor requests a `/stream-server-admin` page
- **THEN** it is handled by the portal, not by the admin portal router

### Requirement: Default portal admin account

The system SHALL create a default portal admin account with email `admin@admin.com` and password `admin` through a portal-database migration, so the portal is accessible on a fresh deployment.

#### Scenario: Fresh deployment has default admin

- **WHEN** portal migrations run on an empty portal database
- **THEN** an admin with email `admin@admin.com` and password `admin` can sign in to the portal

#### Scenario: Migration does not duplicate admin

- **WHEN** portal migrations run on a portal database that already has an admin
- **THEN** no duplicate `admin@admin.com` record is created and no error occurs

### Requirement: Portal sign-in

An unauthenticated visitor SHALL be able to sign in to the portal by submitting a valid email and password through a sign-in form processed by a controller. The sign-in page itself SHALL be rendered by a controller (plain HTML, not LiveView). On success a portal admin session SHALL be established and the visitor redirected to the portal.

#### Scenario: Successful sign-in

- **WHEN** a visitor submits valid portal admin credentials to the portal sign-in endpoint
- **THEN** a portal admin session is established and the visitor is redirected to the portal dashboard

#### Scenario: Invalid credentials

- **WHEN** a visitor submits an unknown email or wrong password
- **THEN** no session is established and the sign-in page is re-rendered with an error message

#### Scenario: Timing-attack resistance

- **WHEN** a sign-in is attempted with a non-existent email
- **THEN** the response behavior is indistinguishable from a wrong-password attempt (no account enumeration)

### Requirement: Portal authentication requirement

Portal pages SHALL only be accessible to authenticated portal admins. Unauthenticated requests SHALL be redirected to the portal sign-in page.

#### Scenario: Unauthenticated access to portal page

- **WHEN** an unauthenticated visitor requests a portal page
- **THEN** they are redirected to the portal sign-in page

#### Scenario: Authenticated access to portal page

- **WHEN** an authenticated portal admin requests a portal page
- **THEN** the page is rendered with the current portal admin's scope available

#### Scenario: Sign-in page redirects authenticated admins

- **WHEN** an authenticated portal admin visits the portal sign-in page
- **THEN** they are redirected to the portal dashboard

### Requirement: Portal sessions independent of admin portal

Portal authentication SHALL be independent of the `/admin` admin portal: a session for one SHALL NOT grant access to the other.

#### Scenario: Admin portal session does not open the portal

- **WHEN** a visitor with a valid `/admin` session but no portal session requests a portal page
- **THEN** they are redirected to the portal sign-in page

#### Scenario: Portal session does not open the admin portal

- **WHEN** a visitor with a valid portal session but no `/admin` session requests an admin portal page
- **THEN** they are redirected to the admin sign-in page

### Requirement: Portal navigation

Authenticated portal pages SHALL render a left sidebar with the portal's navigation: a link to the dashboard, the signed-in admin's email, a link to the settings page, and a log out action. The navigation bar SHALL show the portal brand and an icon button that collapses/expands the sidebar. The log out action SHALL work without client-side JavaScript (form POST with method override to the DELETE route).

#### Scenario: Navigating via the sidebar

- **WHEN** an authenticated portal admin is on any portal page
- **THEN** the sidebar shows a link to the dashboard, the admin's email, a link to the settings page, and a log out button

#### Scenario: Navigating to settings

- **WHEN** an authenticated portal admin activates the settings link in the sidebar
- **THEN** they are taken to the settings page

#### Scenario: Navigating to the dashboard

- **WHEN** an authenticated portal admin activates the dashboard link in the sidebar
- **THEN** they are taken to the portal dashboard

#### Scenario: Log out without JavaScript

- **WHEN** an authenticated portal admin activates the log out button
- **THEN** a form POST is submitted to the log-out endpoint, the session is invalidated, and the admin is redirected to the sign-in page

### Requirement: Portal sidebar visibility

The portal sidebar SHALL be rendered only when a portal admin is authenticated. Pages rendered without an authenticated portal admin SHALL NOT include the sidebar.

#### Scenario: Sidebar hidden when not signed in

- **WHEN** a visitor opens the portal sign-in page without an authenticated portal admin
- **THEN** no sidebar is rendered

#### Scenario: Sidebar shown when signed in

- **WHEN** an authenticated portal admin opens any portal page
- **THEN** the sidebar is rendered

### Requirement: Portal sidebar collapse

The sidebar SHALL be collapsible. The navigation bar SHALL provide an icon button that toggles the sidebar between expanded and collapsed states. Below the `lg` breakpoint the sidebar SHALL behave as a dismissible drawer over the content; at `lg` and above it SHALL be a permanent sidebar.

#### Scenario: Sidebar is a closed drawer on small screens

- **WHEN** an authenticated portal admin opens a portal page on a small viewport
- **THEN** the sidebar is hidden by default and can be opened and dismissed with the toggle or its backdrop

#### Scenario: Collapse the sidebar

- **WHEN** an authenticated portal admin activates the sidebar toggle icon while the sidebar is expanded
- **THEN** the sidebar collapses

#### Scenario: Expand the sidebar

- **WHEN** an authenticated portal admin activates the sidebar toggle icon while the sidebar is collapsed
- **THEN** the sidebar expands

### Requirement: Portal sign-out

An authenticated portal admin SHALL be able to sign out, which SHALL invalidate the portal session and redirect to the portal sign-in page.

#### Scenario: Successful sign-out

- **WHEN** an authenticated portal admin requests sign-out
- **THEN** the portal session token is invalidated, the session is cleared, and the admin is redirected to the portal sign-in page

#### Scenario: Signed-out admin loses access

- **WHEN** a portal admin signs out and then requests a portal page
- **THEN** they are redirected to the portal sign-in page

### Requirement: Portal dashboard

Authenticated portal admins SHALL see a dashboard as the entry point of the portal, rendered with LiveView, providing navigation to portal sections.

#### Scenario: Dashboard renders for admin

- **WHEN** an authenticated portal admin opens `/stream-server-admin`
- **THEN** the dashboard LiveView is rendered with the current portal admin shown

### Requirement: Portal admin password change

An authenticated portal admin SHALL be able to change their password by providing their current password and a new password with confirmation. After a successful change, ALL sessions for that portal admin SHALL be expired, including the current one: the admin SHALL be signed out and redirected to the sign-in page.

#### Scenario: Successful password change signs the admin out

- **WHEN** a portal admin submits their correct current password and a valid new password with matching confirmation
- **THEN** the password is updated, all portal sessions are invalidated, and the admin is redirected to the sign-in page with a confirmation message

#### Scenario: Portal access requires the new password after change

- **WHEN** a portal admin has just changed their password and requests a portal page
- **THEN** they are redirected to the sign-in page and can only sign back in with the new password

#### Scenario: Wrong current password

- **WHEN** a portal admin submits an incorrect current password
- **THEN** the password is not changed and a validation error is shown

#### Scenario: Mismatched confirmation

- **WHEN** the new password confirmation does not match the new password
- **THEN** the password is not changed and a validation error is shown

### Requirement: Portal scope

The system SHALL provide a dedicated portal admin scope that carries the authenticated portal admin, made available to portal controllers and LiveViews as `current_scope`, mirroring the existing admin scope pattern.

#### Scenario: Scope assigned on authenticated request

- **WHEN** an authenticated portal admin accesses any portal page or LiveView
- **THEN** `current_scope.admin` contains the portal admin record

#### Scenario: Scope is nil for unauthenticated requests

- **WHEN** an unauthenticated visitor hits the portal scope-fetching plug
- **THEN** `current_scope` is assigned with no admin (or nil)

### Requirement: Responsive portal UI

Portal pages SHALL render a usable layout across mobile, tablet, and desktop viewport sizes, so admins can sign in and manage settings from any device.

#### Scenario: Mobile viewport

- **WHEN** a portal admin opens any portal page on a small (mobile) viewport
- **THEN** all content and controls are reachable and usable without horizontal scrolling

#### Scenario: Desktop viewport

- **WHEN** a portal admin opens any portal page on a desktop viewport
- **THEN** the layout renders correctly with content appropriately sized and aligned
