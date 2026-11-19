# Admin Portal Specification

## Purpose

Provides a separate administrative web portal where operators sign in with email and password to manage application settings, isolated from the phone-based user authentication while sharing the main application database.

## Requirements

### Requirement: Admin data in shared database

Admin data SHALL be persisted in the main application database in dedicated admin tables (`admins`, `admin_tokens`), with migrations in `priv/repo/migrations` alongside existing migrations, so a single database and migration run covers the whole app.

#### Scenario: Admin records use the main database

- **WHEN** an admin record is created or queried
- **THEN** it is read from and written to dedicated admin tables in the main application database

#### Scenario: Admin migrations run with app migrations

- **WHEN** `mix ecto.migrate` runs
- **THEN** the admin table migrations under `priv/repo/migrations` are applied to the shared database together with the existing migrations

### Requirement: Default admin account

The system SHALL create a default admin account with email `admin@admin.com` and password `admin` through a migration, so the portal is accessible on a fresh deployment.

#### Scenario: Fresh deployment has default admin

- **WHEN** admin portal migrations run on an empty admin database
- **THEN** an admin with email `admin@admin.com` and password `admin` can sign in

#### Scenario: Migration does not duplicate admin

- **WHEN** admin portal migrations run on a database that already has an admin
- **THEN** no duplicate `admin@admin.com` record is created and no error occurs

### Requirement: Admin sign-in

An unauthenticated visitor SHALL be able to sign in to the admin portal by submitting a valid email and password through a sign-in form processed by a controller. The sign-in page itself SHALL be rendered by a controller (plain HTML, not LiveView). On success an admin session SHALL be established and the visitor redirected to the portal.

#### Scenario: Successful sign-in

- **WHEN** a visitor submits valid admin credentials (`admin@admin.com` / `admin`) to the admin sign-in endpoint
- **THEN** an admin session is established and the visitor is redirected to the admin portal dashboard

#### Scenario: Invalid credentials

- **WHEN** a visitor submits an unknown email or wrong password
- **THEN** no session is established and the sign-in page is re-rendered with an error message

#### Scenario: Timing-attack resistance

- **WHEN** a sign-in is attempted with a non-existent email
- **THEN** the response behavior is indistinguishable from a wrong-password attempt (no account enumeration)

### Requirement: Admin authentication requirement

Admin portal pages SHALL only be accessible to authenticated admins. Unauthenticated requests SHALL be redirected to the admin sign-in page.

#### Scenario: Unauthenticated access to portal page

- **WHEN** an unauthenticated visitor requests an admin portal page
- **THEN** they are redirected to the admin sign-in page

#### Scenario: Authenticated access to portal page

- **WHEN** an authenticated admin requests an admin portal page
- **THEN** the page is rendered with the current admin's scope available

#### Scenario: Sign-in page redirects authenticated admins

- **WHEN** an authenticated admin visits the sign-in page
- **THEN** they are redirected to the admin portal dashboard

### Requirement: Admin navigation

Authenticated admin portal pages SHALL render a left sidebar with the portal's navigation: a link to the dashboard, the signed-in admin's email, a link to the settings page, and a log out action. The admin navigation bar SHALL show the portal brand and an icon button that collapses/expands the sidebar. The log out action SHALL work without client-side JavaScript (form POST with method override to the DELETE route).

#### Scenario: Navigating via the sidebar

- **WHEN** an authenticated admin is on any portal page
- **THEN** the sidebar shows a link to the dashboard, the admin's email, a link to the settings page, and a log out button

#### Scenario: Navigating to settings

- **WHEN** an authenticated admin activates the settings link in the sidebar
- **THEN** they are taken to the settings page

#### Scenario: Navigating to the dashboard

- **WHEN** an authenticated admin activates the dashboard link in the sidebar
- **THEN** they are taken to the admin portal dashboard

#### Scenario: Log out without JavaScript

- **WHEN** an authenticated admin activates the log out button
- **THEN** a form POST is submitted to the log-out endpoint, the session is invalidated, and the admin is redirected to the sign-in page

### Requirement: Admin sidebar visibility

The admin sidebar SHALL be rendered only when an admin is authenticated. Pages rendered without an authenticated admin SHALL NOT include the sidebar.

#### Scenario: Sidebar hidden when not signed in

- **WHEN** a visitor opens the admin sign-in page without an authenticated admin
- **THEN** no sidebar is rendered

#### Scenario: Sidebar shown when signed in

- **WHEN** an authenticated admin opens any admin portal page
- **THEN** the sidebar is rendered

### Requirement: Admin sidebar layout and responsiveness

The sidebar SHALL be positioned on the left side of the page with the main content to its right, SHALL adapt to different screen sizes using the project's Tailwind/daisyUI design system, and SHALL remain usable on mobile and desktop viewports.

#### Scenario: Desktop layout

- **WHEN** an authenticated admin opens a portal page on a desktop viewport
- **THEN** the sidebar appears as a column on the left with the main content beside it

#### Scenario: Mobile layout

- **WHEN** an authenticated admin opens a portal page on a small viewport
- **THEN** the sidebar and content remain usable without horizontal scrolling

### Requirement: Admin sidebar collapse

The sidebar SHALL be collapsible. The admin navigation bar SHALL provide an icon button that toggles the sidebar between expanded and collapsed states.

#### Scenario: Collapse the sidebar

- **WHEN** an authenticated admin activates the sidebar toggle icon while the sidebar is expanded
- **THEN** the sidebar collapses

#### Scenario: Expand the sidebar

- **WHEN** an authenticated admin activates the sidebar toggle icon while the sidebar is collapsed
- **THEN** the sidebar expands

### Requirement: Admin sign-out

An authenticated admin SHALL be able to sign out, which SHALL invalidate the admin session and redirect to the sign-in page.

#### Scenario: Successful sign-out

- **WHEN** an authenticated admin requests sign-out
- **THEN** the admin session token is invalidated, the session is cleared, and the admin is redirected to the sign-in page

#### Scenario: Signed-out admin loses access

- **WHEN** an admin signs out and then requests an admin portal page
- **THEN** they are redirected to the sign-in page

### Requirement: Admin portal dashboard

Authenticated admins SHALL see a dashboard as the entry point of the admin portal, rendered with LiveView, providing navigation to portal sections.

#### Scenario: Dashboard renders for admin

- **WHEN** an authenticated admin opens the admin portal root
- **THEN** the dashboard LiveView is rendered with the current admin shown

### Requirement: Admin password change

An authenticated admin SHALL be able to change their password from the admin portal by providing their current password and a new password with confirmation. After a successful change, ALL sessions for that admin SHALL be expired, including the current one: the admin SHALL be signed out and redirected to the sign-in page.

#### Scenario: Successful password change signs the admin out

- **WHEN** an admin submits their correct current password and a valid new password with matching confirmation
- **THEN** the password is updated, all admin sessions are invalidated, and the admin is redirected to the sign-in page with a confirmation message

#### Scenario: Portal access requires the new password after change

- **WHEN** an admin has just changed their password and requests an admin portal page
- **THEN** they are redirected to the sign-in page and can only sign back in with the new password

#### Scenario: Wrong current password

- **WHEN** an admin submits an incorrect current password
- **THEN** the password is not changed and a validation error is shown

#### Scenario: Mismatched confirmation

- **WHEN** the new password confirmation does not match the new password
- **THEN** the password is not changed and a validation error is shown

### Requirement: Flash notifications

Admin portal flash notifications SHALL be dismissible manually via a close (X) button and SHALL also dismiss automatically after a short delay (about 3 seconds). Both behaviors SHALL work on controller-rendered pages without a connected LiveView socket, and SHALL NOT apply to LiveView connectivity alerts.

#### Scenario: Manual dismissal

- **WHEN** an admin clicks the X button on a flash notification on any admin page
- **THEN** the notification is dismissed

#### Scenario: Automatic dismissal

- **WHEN** a flash notification is shown on an admin page
- **THEN** it is dismissed automatically after about 3 seconds without interaction

### Requirement: Responsive admin UI

Admin portal pages SHALL render a usable layout across desktop and mobile viewport sizes, so admins can sign in and manage settings from any device.

#### Scenario: Mobile viewport

- **WHEN** an admin opens any portal page on a small (mobile) viewport
- **THEN** all content and controls are reachable and usable without horizontal scrolling

#### Scenario: Desktop viewport

- **WHEN** an admin opens any portal page on a desktop viewport
- **THEN** the layout renders correctly with content appropriately sized and aligned

### Requirement: Admin scope

The system SHALL provide a dedicated admin scope (`VideoConference.AdminPortal.Accounts.Scope`) that carries the authenticated admin, made available to admin controllers and LiveViews as `current_scope`, mirroring the existing phone scope pattern.

#### Scenario: Scope assigned on authenticated request

- **WHEN** an authenticated admin accesses any admin portal page or LiveView
- **THEN** `current_scope.admin` contains the admin record

#### Scenario: Scope is nil for unauthenticated requests

- **WHEN** an unauthenticated visitor hits the admin scope-fetching plug
- **THEN** `current_scope` is assigned with no admin (or nil)
