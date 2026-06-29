defmodule VideoConferenceWeb.SharedLinkController do
  use VideoConferenceWeb, :controller

  action_fallback VideoConferenceWeb.FallbackController

  alias VideoConference.SharedLinks
  alias VideoConference.SharedLinks.SharedLink

  def list(conn, _params) do
    shared_links = SharedLinks.list(conn.assigns.current_scope)

    render(conn, :shared_links, shared_links: shared_links)
  end

  def generate(conn, %{"name" => name, "password" => password}) do
    SharedLinks.generate(conn.assigns.current_scope, %{
      "name" => name,
      "password" => password
    })
    |> case do
      {:ok, %SharedLink{} = shared_link} ->
        render(conn, :shared_link, shared_link: shared_link)

      error ->
        error
    end
  end

  def generate(conn, %{"name" => name}) do
    SharedLinks.generate(conn.assigns.current_scope, %{
      "name" => name
    })
    |> case do
      {:ok, %SharedLink{} = shared_link} ->
        render(conn, :shared_link, shared_link: shared_link)

      error ->
        error
    end
  end

  def disable_password(conn, %{"id" => id}) do
    SharedLinks.disable_password(conn.assigns.current_scope, %{"id" => id})
    |> case do
      {:ok, %SharedLink{} = shared_link} ->
        render(conn, :disable_password, shared_link: shared_link)

      error ->
        error
    end
  end

  def enable_password(conn, %{"id" => id, "password" => password}) do
    SharedLinks.enable_password(conn.assigns.current_scope, %{"id" => id, "password" => password})
    |> case do
      {:ok, %SharedLink{} = shared_link} ->
        render(conn, :enable_password, shared_link: shared_link)

      error ->
        error
    end
  end
end
