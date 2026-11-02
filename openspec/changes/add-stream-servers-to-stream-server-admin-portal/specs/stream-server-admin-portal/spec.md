# Spec Delta

## MODIFIED Requirements

### Requirement: Portal navigation

Authenticated portal pages SHALL render a left sidebar with the portal's navigation: a link to the dashboard, a "Stream servers" item, an "Applications" item with an "API keys" sub-item, the signed-in admin's email, a link to the settings page, and a log out action. The navigation bar SHALL show the portal brand and an icon button that collapses/expands the sidebar. The log out action SHALL work without client-side JavaScript (form POST with method override to the DELETE route).

#### Scenario: Navigating via the sidebar

- **WHEN** an authenticated portal admin is on any portal page
- **THEN** the sidebar shows a link to the dashboard, a "Stream servers" item, an "Applications" item with an "API keys" sub-item, the admin's email, a link to the settings page, and a log out button

#### Scenario: Navigating to settings

- **WHEN** an authenticated portal admin activates the settings link in the sidebar
- **THEN** they are taken to the settings page

#### Scenario: Navigating to the dashboard

- **WHEN** an authenticated portal admin activates the dashboard link in the sidebar
- **THEN** they are taken to the portal dashboard

#### Scenario: Navigating to stream servers

- **WHEN** an authenticated portal admin activates the "Stream servers" item in the sidebar
- **THEN** they are taken to the stream servers page

#### Scenario: Navigating to applications

- **WHEN** an authenticated portal admin activates the "Applications" item in the sidebar
- **THEN** they are taken to the applications page

#### Scenario: Navigating to API keys

- **WHEN** an authenticated portal admin activates the "API keys" sub-item in the sidebar
- **THEN** they are taken to the API keys page

#### Scenario: Log out without JavaScript

- **WHEN** an authenticated portal admin activates the log out button
- **THEN** a form POST is submitted to the log-out endpoint, the session is invalidated, and the admin is redirected to the sign-in page
