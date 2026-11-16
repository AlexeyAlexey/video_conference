defmodule VideoConferenceWeb.StreamServerAdminPortal.AdminComponents do
  @moduledoc """
  Function components shared by the stream server admin portal layout.
  """
  use VideoConferenceWeb, :html

  @doc """
  Renders the stream server admin portal sidebar with the portal
  navigation: a link to the dashboard, a "Stream servers" item with its
  "API keys" sub-item, an "Applications" item with its
  "API keys", "Stream server public keys" and "Stream servers" sub-items,
  the signed-in admin's email, a
  link to the settings page with its "Change password" sub-item, and a
  log out button. Rendered only when an admin is authenticated.
  """
  attr :current_scope, :map,
    required: true,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :collapsed, :boolean,
    default: false,
    doc: "whether the sidebar is collapsed"

  def admin_sidebar(assigns) do
    ~H"""
    <div
      :if={@current_scope && @current_scope.admin && not @collapsed}
      id="stream-server-admin-sidebar-backdrop"
      phx-click="toggle_admin_sidebar"
      class="fixed inset-x-0 bottom-0 top-16 z-30 bg-black/50 lg:hidden"
      aria-hidden="true"
    >
    </div>
    <aside
      :if={@current_scope && @current_scope.admin}
      id="stream-server-admin-sidebar"
      class={[
        "fixed top-16 bottom-0 left-0 z-40 w-64 shrink-0 overflow-y-auto",
        "border-r border-base-300 bg-base-200 lg:static lg:z-auto lg:block",
        "lg:min-h-[calc(100vh-4rem)]",
        @collapsed && "hidden"
      ]}
    >
      <ul class="menu w-full gap-1 p-4">
        <li>
          <.link id="sidebar-dashboard-link" navigate="/stream-server-admin">
            <.icon name="hero-home" class="size-4" /> Dashboard
          </.link>
        </li>
        <li>
          <.link
            id="sidebar-stream-servers-link"
            navigate="/stream-server-admin/stream-servers"
          >
            <.icon name="hero-server-stack" class="size-4" /> Stream servers
          </.link>
          <ul>
            <li>
              <.link
                id="sidebar-stream-server-api-keys-link"
                navigate="/stream-server-admin/stream-servers/api-keys"
              >
                API keys
              </.link>
            </li>
          </ul>
        </li>
        <li>
          <.link id="sidebar-applications-link" navigate="/stream-server-admin/applications">
            <.icon name="hero-squares-2x2" class="size-4" /> Applications
          </.link>
          <ul>
            <li>
              <.link id="sidebar-api-keys-link" navigate="/stream-server-admin/api-keys">
                API keys
              </.link>
            </li>
            <li>
              <.link
                id="sidebar-stream-server-public-keys-link"
                navigate="/stream-server-admin/applications/stream-server-public-keys"
              >
                Stream server public keys
              </.link>
            </li>
            <li>
              <.link
                id="sidebar-application-stream-servers-link"
                navigate="/stream-server-admin/applications/stream-servers"
              >
                Stream servers
              </.link>
            </li>
          </ul>
        </li>
        <li class="menu-title">
          <span id="stream-server-admin-sidebar-email" class="truncate">
            {@current_scope.admin.email}
          </span>
        </li>
        <li>
          <.link id="sidebar-settings-link" navigate="/stream-server-admin/settings">
            <.icon name="hero-cog-6-tooth" class="size-4" /> Settings
          </.link>
          <ul>
            <li>
              <.link id="sidebar-change-password-link" navigate="/stream-server-admin/settings">
                Change password
              </.link>
            </li>
          </ul>
        </li>
        <li>
          <form action="/stream-server-admin/log-out" method="post">
            <input type="hidden" name="_method" value="delete" />
            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
            <button type="submit" class="btn btn-outline btn-sm w-full">Log out</button>
          </form>
        </li>
      </ul>
    </aside>
    """
  end
end
