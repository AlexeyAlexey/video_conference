defmodule VideoConferenceWeb.Router do
  use VideoConferenceWeb, :router

  import VideoConferenceWeb.AccountAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VideoConferenceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_user_token
    plug :put_http3_server_cert_hash
    plug :put_http3_server_host_and_port
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_api_authentication do
    plug :fetch_current_scope_for_api
  end

  scope "/", VideoConferenceWeb do
    pipe_through :api

    # post "/log", LogController, :log
    post "/phones/register", PhoneRegistrationController, :register
    post "/phones/log-in", PhoneSessionController, :log_in

    get "/conference/public/shared_link/info/:link_id", SharedLinkPublicController, :info

    post "/conference/public/shared_link/conference_credentials/:link_id",
         SharedLinkPublicController,
         :conference_credentials
  end

  scope "/", VideoConferenceWeb do
    pipe_through [:api, :require_api_authentication]

    delete "/phones/log-out", PhoneSessionController, :log_out
    post "/phone_book/add_phone", PhoneBookController, :add_phone
    delete "/phone_book/remove_phone", PhoneBookController, :remove_phone
    get "/phone_book/list", PhoneBookController, :list

    get "/shared_link/list", SharedLinkController, :list
    post "/shared_link/generate", SharedLinkController, :generate
    post "/shared_link/enable_password", SharedLinkController, :enable_password
    post "/shared_link/disable_password", SharedLinkController, :disable_password
    patch "/shared_link/rename", SharedLinkController, :rename
    delete "/shared_link/remove", SharedLinkController, :remove
  end

  scope "/", VideoConferenceWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", VideoConferenceWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:video_conference, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VideoConferenceWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  defp put_user_token(conn, _) do
    assign(conn, :user_token, Ecto.UUID.generate())
  end

  defp put_http3_server_cert_hash(conn, _) do
    assign(conn, :http3_server_cert_hash, System.get_env("HTTP3_SERVER_CERT_HASH"))
  end

  defp put_http3_server_host_and_port(conn, _) do
    assign(conn, :http3_server_host, System.get_env("HTTP3_SERVER_HOST"))
    |> assign(:http3_server_port, System.get_env("HTTP3_SERVER_PORT"))
  end

  ## Authentication routes

  # scope "/", VideoConferenceWeb do
  #   pipe_through [:browser, :redirect_if_phone_is_authenticated]

  #   get "/phones/register", PhoneRegistrationController, :new
  #   post "/phones/register", PhoneRegistrationController, :create
  # end

  # scope "/", VideoConferenceWeb do
  #   pipe_through [:browser, :require_authenticated_phone]

  #   get "/phones/settings", PhoneSettingsController, :edit
  #   put "/phones/settings", PhoneSettingsController, :update
  #   get "/phones/settings/confirm-email/:token", PhoneSettingsController, :confirm_email
  # end

  # scope "/", VideoConferenceWeb do
  #   pipe_through [:browser]

  #   get "/phones/log-in", PhoneSessionController, :new
  #   get "/phones/log-in/:token", PhoneSessionController, :confirm
  #   post "/phones/log-in", PhoneSessionController, :create
  #   delete "/phones/log-out", PhoneSessionController, :delete
  # end
end
