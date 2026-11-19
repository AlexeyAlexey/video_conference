defmodule VideoConferenceWeb.AdminPortal.AdminComponents do
  @moduledoc """
  Function components shared by the admin portal layout.
  """
  use VideoConferenceWeb, :html

  @doc """
  Renders the admin portal sidebar with the portal navigation: a link to
  the dashboard, links to the known hosts and stream servers pages, the
  signed-in admin's
  email, a link to the settings page with its "Change password" sub-item,
  and a log out button. Rendered only when an admin is authenticated.
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
      id="admin-sidebar-backdrop"
      phx-click="toggle_admin_sidebar"
      class="fixed inset-x-0 bottom-0 top-16 z-30 bg-black/50 lg:hidden"
      aria-hidden="true"
    >
    </div>
    <aside
      :if={@current_scope && @current_scope.admin}
      id="admin-sidebar"
      class={[
        "fixed top-16 bottom-0 left-0 z-40 w-64 shrink-0 overflow-y-auto",
        "border-r border-base-300 bg-base-200 lg:static lg:z-auto lg:block",
        "lg:min-h-[calc(100vh-4rem)]",
        @collapsed && "hidden"
      ]}
    >
      <ul class="menu w-full gap-1 p-4">
        <li>
          <.link id="sidebar-dashboard-link" navigate="/admin">
            <.icon name="hero-home" class="size-4" /> Dashboard
          </.link>
        </li>
        <li>
          <.link id="sidebar-known-hosts-link" navigate="/admin/known-hosts">
            <.icon name="hero-server-stack" class="size-4" /> Known hosts
          </.link>
        </li>
        <li>
          <.link id="sidebar-stream-servers-link" navigate="/admin/stream-servers">
            <.icon name="hero-signal" class="size-4" /> Stream servers
          </.link>
          <ul>
            <li>
              <.link id="sidebar-public-keys-link" navigate="/admin/stream-servers/keys">
                Public keys
              </.link>
            </li>
          </ul>
        </li>
        <li class="menu-title">
          <span id="admin-sidebar-email" class="truncate">{@current_scope.admin.email}</span>
        </li>
        <li>
          <.link id="sidebar-settings-link" navigate="/admin/settings">
            <.icon name="hero-cog-6-tooth" class="size-4" /> Settings
          </.link>
          <ul>
            <li>
              <.link id="sidebar-change-password-link" navigate="/admin/settings">
                Change password
              </.link>
            </li>
          </ul>
        </li>
        <li>
          <form action="/admin/log-out" method="post">
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
