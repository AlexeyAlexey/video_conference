defmodule VideoConferenceWeb.StreamServerAdminPortal.Router do
  use VideoConferenceWeb, :router

  import VideoConferenceWeb.StreamServerAdminPortal.AdminAuth

  alias VideoConferenceWeb.StreamServerAdminPortal.ApiKeyAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VideoConferenceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_admin
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", VideoConferenceWeb.StreamServerAdminPortal do
    pipe_through [:api, ApiKeyAuth]

    get "/api/stream-server/public-key", PublicKeyController, :show
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

      live "/applications/stream-server-public-keys",
           StreamServerPublicKeysLive,
           :index

      live "/applications/stream-servers",
           ApplicationStreamServersLive,
           :index

      live "/api-keys", ApiKeysLive, :index
      live "/stream-servers", StreamServersLive, :index
      live "/stream-servers/new", StreamServersLive, :new
      live "/stream-servers/:id/assign", StreamServersLive, :assign
      live "/stream-servers/api-keys", StreamServerApiKeysLive, :index

      # Mirror routes for LiveView URL resolution only, see the note below.
      live "/stream-server-admin", DashboardLive, :index
      live "/stream-server-admin/settings", SettingsLive, :edit
      live "/stream-server-admin/applications", ApplicationsLive, :index
      live "/stream-server-admin/applications/new", ApplicationsLive, :new

      live "/stream-server-admin/applications/stream-server-public-keys",
           StreamServerPublicKeysLive,
           :index

      live "/stream-server-admin/applications/stream-servers",
           ApplicationStreamServersLive,
           :index

      live "/stream-server-admin/api-keys", ApiKeysLive, :index
      live "/stream-server-admin/stream-servers", StreamServersLive, :index
      live "/stream-server-admin/stream-servers/new", StreamServersLive, :new
      live "/stream-server-admin/stream-servers/:id/assign", StreamServersLive, :assign

      live "/stream-server-admin/stream-servers/api-keys",
           StreamServerApiKeysLive,
           :index
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
