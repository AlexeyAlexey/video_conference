# Proposal

## Why

The admin portal currently exposes navigation only through a top navbar, which does not scale as portal sections grow and does not match the conventional admin-panel layout admins expect. A dedicated left sidebar gives the portal room to grow and provides a persistent, collapsible navigation surface.

## What Changes

- Add a left sidebar to authenticated admin portal pages containing: a Dashboard link, the signed-in admin's email (from `@current_scope.admin.email`), a Settings link, and a Log out action (form POST, still works without JavaScript).
- The sidebar is rendered only when an admin is authenticated; unauthenticated pages (e.g. the log-in page) do not show it.
- The sidebar sits on the left side of the page, with main content to its right.
- The sidebar is responsive: on small viewports it overlays content; on desktop it can sit as a static column beside the content.
- The admin navbar gains an icon button to collapse/expand the sidebar.
- Navigation items currently in the navbar (admin email, Settings link, Log out) move into the sidebar; the navbar keeps the portal brand and the collapse toggle.
- The sidebar is styled with the existing Tailwind CSS 4 + daisyUI design system (`menu`, `drawer`, `btn`, `base-*` color tokens).

## Capabilities

### New Capabilities

- None — the sidebar is an extension of the existing admin portal navigation behavior.

### Modified Capabilities

- `admin-portal`: the "Admin navigation" requirement changes — navigation moves from a top-navbar-only layout to a left sidebar (Dashboard, admin email, Settings, Log out) plus a navbar collapse/expand toggle icon. Adds new requirement(s) covering sidebar visibility (authenticated only), positioning, responsiveness, and collapsibility.

## Impact

- `lib/video_conference_web/components/layouts.ex` — the `admin` layout gains the sidebar markup and the navbar toggle.
- `lib/video_conference_web/admin_portal/live/dashboard_live.ex`, `settings_live.ex` — unchanged call sites (`<Layouts.admin>`), but rendered output changes.
- `test/video_conference_web/admin_portal/live/dashboard_live_test.exs`, `settings_live_test.exs`, `controllers/session_controller_test.exs` — assertions that target navbar items (`#admin-navbar-email`, `#nav-settings-link`, log-out form placement) need updating to target the sidebar.
- No new dependencies, no router changes, no API changes.
- Manual browser validation of collapse/expand, responsiveness, and navigation on a running dev server.
