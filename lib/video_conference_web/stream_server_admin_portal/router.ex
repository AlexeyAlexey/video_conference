defmodule VideoConferenceWeb.StreamServerAdminPortal.Router do
  use VideoConferenceWeb, :router

  import VideoConferenceWeb.StreamServerAdminPortal.AdminAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VideoConferenceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_admin
  end

  scope "/", VideoConferenceWeb.StreamServerAdminPortal do
    pipe_through [:browser, :redirect_if_admin_is_authenticated]

    get "/log-in", SessionController, :new
    post "/log-in", SessionController, :create
  end

  scope "/", VideoConferenceWeb.StreamServerAdminPortal do
    pipe_through [:browser, :require_authenticated_admin]

    delete "/log-out", SessionController, :delete
    post "/update-password", SessionController, :update_password

    live_session :stream_server_admin,
      on_mount: [
        {VideoConferenceWeb.StreamServerAdminPortal.AdminAuth, :mount_current_scope},
        {VideoConferenceWeb.StreamServerAdminPortal.AdminAuth, :ensure_authenticated},
        {VideoConferenceWeb.StreamServerAdminPortal.AdminAuth, :admin_sidebar}
      ] do
      live "/", DashboardLive, :index
      live "/settings", SettingsLive, :edit
      live "/applications", ApplicationsLive, :index
      live "/applications/new", ApplicationsLive, :new
      live "/applications/:id/edit", ApplicationsLive, :edit
      live "/api-keys", ApiKeysLive, :index
      live "/api-keys/new", ApiKeysLive, :new
      live "/api-keys/:id/edit", ApiKeysLive, :edit
      live "/stream-servers", StreamServersLive, :index
      live "/stream-servers/new", StreamServersLive, :new
      live "/stream-servers/:id/edit", StreamServersLive, :edit
      live "/stream-servers/:id/assign", StreamServersLive, :assign

      # Mirror routes for LiveView URL resolution only, see the note below.
      live "/stream-server-admin", DashboardLive, :index
      live "/stream-server-admin/settings", SettingsLive, :edit
      live "/stream-server-admin/applications", ApplicationsLive, :index
      live "/stream-server-admin/applications/new", ApplicationsLive, :new
      live "/stream-server-admin/applications/:id/edit", ApplicationsLive, :edit
      live "/stream-server-admin/api-keys", ApiKeysLive, :index
      live "/stream-server-admin/api-keys/new", ApiKeysLive, :new
      live "/stream-server-admin/api-keys/:id/edit", ApiKeysLive, :edit
      live "/stream-server-admin/stream-servers", StreamServersLive, :index
      live "/stream-server-admin/stream-servers/new", StreamServersLive, :new
      live "/stream-server-admin/stream-servers/:id/edit", StreamServersLive, :edit
      live "/stream-server-admin/stream-servers/:id/assign", StreamServersLive, :assign
    end
  end

  # The main router forwards "/stream-server-admin" to this router, so at
  # dispatch time this router sees the stripped path ("/", "/settings").
  # LiveView channel mounts, however, verify that the public connect URL
  # ("/stream-server-admin/...") resolves to the same LiveView and
  # live_session in this router. The "/stream-server-admin"-prefixed mirror
  # routes above exist only so that `Phoenix.Router.route_info/4` resolves
  # those public paths; they are never hit at dispatch time because requests
  # always arrive stripped.
end
