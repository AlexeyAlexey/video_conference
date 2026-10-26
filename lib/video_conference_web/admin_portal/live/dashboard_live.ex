defmodule VideoConferenceWeb.AdminPortal.DashboardLive do
  use VideoConferenceWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Admin Dashboard")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto w-full max-w-md px-2 sm:px-0">
        <.header>
          Admin Dashboard
          <:subtitle>Signed in as {@current_scope.admin.email}</:subtitle>
        </.header>

        <div class="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <.link
            navigate="/admin/settings"
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
    </Layouts.admin>
    """
  end
end
