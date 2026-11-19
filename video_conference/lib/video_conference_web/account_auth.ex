defmodule VideoConferenceWeb.AccountAuth do
  use VideoConferenceWeb, :verified_routes

  require Logger

  import Plug.Conn
  # import Phoenix.Controller

  alias VideoConference.Accounts
  alias VideoConference.Accounts.Scope
  alias VideoConference.AccountAuthToken

  def fetch_current_scope_for_api(conn, _opts) do
    with {:ok, session_token} <-
           fetch_session_token(conn),
         {:ok, {session, _token_inserted_at}} <-
           Accounts.get_by_session_token(session_token) do
      conn
      |> assign(:current_scope, Scope.for(session))
      |> assign(:current_session_token, session_token)
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(:unauthorized, Jason.encode!(%{error: "Unauthorized"}))
        |> halt()
    end
  end

  def fetch_current_scope_for_socket(auth_token) when is_binary(auth_token) do
    with {:ok, auth_token} <- AccountAuthToken.verify_and_validate(auth_token),
         {:ok, session_token64} <- Map.fetch(auth_token, "session_token"),
         {:ok, session_token} <- Base.url_decode64(session_token64, padding: false),
         {:ok, {session, _token_inserted_at}} <-
           Accounts.get_by_session_token(session_token) do
      {:ok, Scope.for(session)}
    else
      {:error, error} ->
        {:error, error}
    end
  end

  defp fetch_session_token(conn) do
    with [<<bearer::binary-size(6), " ", auth_token::binary>>] <-
           get_req_header(conn, "authorization"),
         true <- String.downcase(bearer) == "bearer",
         {:ok, auth_token} <- AccountAuthToken.verify_and_validate(auth_token) do
      if session_token = auth_token["session_token"] do
        Base.url_decode64(session_token, padding: false)
      else
        {:error, :auth_token_without_session_token}
      end
    else
      error ->
        Logger.error("Failed fetch session token #{inspect(error)}")
        {:error, :failed_to_fetch_token}
    end
  end
end
