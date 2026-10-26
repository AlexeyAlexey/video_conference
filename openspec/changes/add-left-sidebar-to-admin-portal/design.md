# Design

## Context

The admin portal shares one layout function — `Layouts.admin/1` in `lib/video_conference_web/components/layouts.ex` — across the controller-rendered log-in page and the authenticated LiveViews (`DashboardLive`, `SettingsLive`). It currently renders a top navbar with the brand plus (when `@current_scope.admin` is set) the admin email, a Settings link, and a no-JS log-out form. See proposal.md for motivation and `specs/admin-portal/spec.md` for the behavior contract.

Relevant constraints from the codebase:

- All authenticated admin pages are LiveViews in the `:admin` `live_session`; the only controller-rendered admin page is `/admin/log-in`, which renders the same layout with no authenticated admin.
- `assets/js/app.js` is bundled into every page; modules must be import-safe, so new client-side JS should be avoided in favor of server-rendered behavior.
- The design system is Tailwind CSS 4 + daisyUI 5 (`navbar`, `menu`, `btn`, `base-*` tokens) already used throughout the layout.
- The admin router is reached via `forward "/admin"`, so all links use literal `/admin/...` paths, not `~p` verified routes.

## Goals / Non-Goals

**Goals:**

- Restructure `Layouts.admin` so authenticated pages render: navbar (brand + sidebar toggle icon), a left sidebar (Dashboard, admin email, Settings, Log out), and the main content to its right.
- Keep the log-out action as a form POST with `_method=delete` inside the sidebar.
- Collapse/expand driven by a navbar icon button, working at all viewport sizes.
- Responsive: static left column on desktop; usable overlay/hidden behavior on mobile without horizontal scrolling.

**Non-Goals:**

- Persisting collapse state across page loads (no localStorage/cookies in this change).
- Changing routes, auth logic, or any controller/LiveView module behavior.
- Sidebar on unauthenticated pages.

## Decisions

### Decision: Sidebar lives in `Layouts.admin`, gated on `@current_scope.admin`

The layout already conditionally renders navbar items via `:if={@current_scope && @current_scope.admin}`. The sidebar uses the same guard, which automatically satisfies "hidden when not logged in" and covers every authenticated page without touching the LiveViews. The `<aside>` markup is encapsulated in an `admin_sidebar` function component (`VideoConferenceWeb.AdminPortal.AdminComponents`) so the layout stays readable and the sidebar can grow (e.g. the "Change password" sub-item under Settings) without cluttering `Layouts.admin`.

### Decision: Collapse state as a LiveView socket assign, toggled via `phx-click` handled by an `attach_hook`

The toggle button emits `phx-click="toggle_admin_sidebar"`. A shared `attach_hook` (registered in `AdminAuth.mount_current_scope`'s `on_mount`, or a small dedicated `on_mount` module added to the `:admin` live_session) handles the event and flips an `admin_sidebar_collapsed` assign, which drives Tailwind classes on the `<aside>`.

Alternatives considered:

- **daisyUI `drawer` + hidden checkbox (no JS):** `drawer-side` is an overlay at all sizes; `lg:drawer-open` makes it a static desktop column but then it cannot be collapsed on desktop, violating the collapse requirement. Combining both modes needs bespoke CSS beyond stock classes.
- **`Phoenix.LiveView.JS.toggle_class` on the sidebar element:** purely client-side, but LiveView's morphdom re-applies server-rendered attributes on every patch, so a client-toggled class on an element inside the LV-rendered layout is reverted on the next patch. Server-side assign state survives patching correctly.
- **Custom app.js hook / DOM script:** rejected — adds import-safety risk to the shared bundle for behavior the server can render.

Because the sidebar only renders on LiveView pages, requiring a connected socket for the toggle is acceptable; the spec only mandates no-JS for log out.

### Decision: Responsive layout via Tailwind classes on a flex wrapper

Inside the layout, after the navbar, render `<div class="flex">` containing the `<aside>` sidebar and `<main>`. Expanded state: visible at all sizes — `fixed`/`absolute` overlay on small screens, `md:static` static column (~`w-64`, daisyUI `menu`) on `md:` and up. Collapsed state: `hidden` everywhere. Content sits in `<main class="flex-1 ...">`.

## Risks / Trade-offs

- [Collapse toggle needs a connected LiveView] → Acceptable: every page that shows the sidebar is a LiveView; log-in page has no sidebar. Log out stays no-JS.
- [Collapse state resets on full page reload / LV remount] → Documented non-goal; revisit persistence only if requested.
- [Overlay sidebar on mobile could obscure content] → Toggle defaults to collapsed on first mobile render is a styling choice made in implementation via responsive classes; tests assert usability, not a specific default.
- [Existing tests assert navbar item ids (`#admin-navbar-email`, `#nav-settings-link`)] → Tests are updated to target the sidebar equivalents in the same test pass.

## Migration Plan

Pure UI change in the shared layout plus test updates. Deploy with a normal release; rollback by reverting the layout change. No data or API migration.

## Open Questions

- Exact icon choice for the toggle (e.g. `hero-bars-3`) and whether the navbar keeps duplicate items (email) — decided during implementation; both satisfy the spec.
