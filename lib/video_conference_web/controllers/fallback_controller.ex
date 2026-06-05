defmodule VideoConferenceWeb.FallbackController do
  use Phoenix.Controller, formats: [:json]

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: VideoConferenceWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(403)
    |> put_view(json: VideoConferenceWeb.ErrorJSON)
    |> render(:"403")
  end

  def call(conn, {:error, "Invalid phone or password"}) do
    conn
    |> put_status(401)
    |> put_view(json: VideoConferenceWeb.ErrorJSON)
    |> render(:"401", detail: "Invalid phone or password")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: VideoConferenceWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
