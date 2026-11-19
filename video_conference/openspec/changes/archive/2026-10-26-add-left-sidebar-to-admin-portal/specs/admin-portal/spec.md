# Spec Delta

## MODIFIED Requirements

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

## ADDED Requirements

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
