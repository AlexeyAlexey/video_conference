defmodule VideoConferenceWeb.StreamServerAdminPortal.DashboardLive do
  use VideoConferenceWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Stream Server Admin Dashboard")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.stream_server_admin
      flash={@flash}
      current_scope={@current_scope}
      admin_sidebar_collapsed={@admin_sidebar_collapsed}
    >
      <div class="mx-auto w-full max-w-md px-2 sm:px-0">
        <.header>
          Stream Server Admin Dashboard
          <:subtitle>Signed in as {@current_scope.admin.email}</:subtitle>
        </.header>

        <div class="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.link
            navigate="/stream-server-admin/applications"
            id="applications-link"
            class="card bg-base-200 hover:bg-base-300 transition-colors p-4 sm:p-6"
          >
            <div class="flex items-center gap-3">
              <.icon name="hero-squares-2x2" class="size-6" />
              <div>
                <h2 class="font-semibold">Applications</h2>
                <p class="text-sm opacity-70">Manage third-party applications</p>
              </div>
            </div>
          </.link>
          <.link
            navigate="/stream-server-admin/api-keys"
            id="api-keys-link"
            class="card bg-base-200 hover:bg-base-300 transition-colors p-4 sm:p-6"
          >
            <div class="flex items-center gap-3">
              <.icon name="hero-key" class="size-6" />
              <div>
                <h2 class="font-semibold">API keys</h2>
                <p class="text-sm opacity-70">Manage application credentials</p>
              </div>
            </div>
          </.link>
          <.link
            navigate="/stream-server-admin/settings"
            id="settings-link"
            class="card bg-base-200 hover:bg-base-300 transition-colors p-4 sm:p-6"
          >
            <div class="flex items-center gap-3">
              <.icon name="hero-cog-6-tooth" class="size-6" />
              <div>
                <h2 class="font-semibold">Settings</h2>
                <p class="text-sm opacity-70">Change your password</p>
              </div>
            </div>
          </.link>
        </div>
      </div>
    </Layouts.stream_server_admin>
    """
  end
end
