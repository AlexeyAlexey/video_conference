defmodule VideoConferenceWeb.Router do
  use VideoConferenceWeb, :router

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

  scope "/", VideoConferenceWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", VideoConferenceWeb do
    pipe_through :api

    post "/log", LogController, :log
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
end
