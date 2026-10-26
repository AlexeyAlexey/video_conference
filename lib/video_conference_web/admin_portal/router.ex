defmodule VideoConferenceWeb.AdminPortal.Router do
  use VideoConferenceWeb, :router

  import VideoConferenceWeb.AdminPortal.AdminAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VideoConferenceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_admin
  end

  scope "/", VideoConferenceWeb.AdminPortal do
    pipe_through [:browser, :redirect_if_admin_is_authenticated]

    get "/log-in", SessionController, :new
    post "/log-in", SessionController, :create
  end

  scope "/", VideoConferenceWeb.AdminPortal do
    pipe_through [:browser, :require_authenticated_admin]

    delete "/log-out", SessionController, :delete
    post "/update-password", SessionController, :update_password

    live_session :admin,
      on_mount: [
        {VideoConferenceWeb.AdminPortal.AdminAuth, :mount_current_scope},
        {VideoConferenceWeb.AdminPortal.AdminAuth, :ensure_authenticated},
        {VideoConferenceWeb.AdminPortal.AdminAuth, :admin_sidebar}
      ] do
      live "/", DashboardLive, :index
      live "/settings", SettingsLive, :edit

      # Mirror routes for LiveView URL resolution only, see the note below.
      live "/admin", DashboardLive, :index
      live "/admin/settings", SettingsLive, :edit
    end
  end

  # The main router forwards "/admin" to this router, so at dispatch time
  # this router sees the stripped path ("/", "/settings"). LiveView channel
  # mounts, however, verify that the public connect URL ("/admin/...")
  # resolves to the same LiveView and live_session in this router. The
  # "/admin"-prefixed mirror routes above exist only so that
  # `Phoenix.Router.route_info/4` resolves those public paths; they are
  # never hit at dispatch time because requests always arrive stripped.
end
