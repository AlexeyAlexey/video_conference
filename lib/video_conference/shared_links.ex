defmodule VideoConference.SharedLinks do
  @moduledoc """
  The Shared Link context.
  """

  import Ecto.Query, warn: false
  alias VideoConference.Repo

  alias VideoConference.SharedLinks.SharedLink
  alias VideoConference.Accounts.Scope
  alias VideoConference.Accounts.Phone

  def list(%Scope{phone: %Phone{id: phone_id}}) do
    Repo.all(from s in SharedLink, where: s.phone_id == ^phone_id, order_by: s.name)
  end

  def generate(%Scope{phone: %Phone{id: phone_id}} = scope, %{
        "name" => name,
        "password" => password
      }) do
    password_required = true

    %SharedLink{}
    |> SharedLink.generate_changeset(
      %{
        "phone_id" => phone_id,
        "name" => name,
        "link_id" => generate_link_id(scope),
        "password" => password,
        "password_required" => password_required
      },
      password_required: password_required
    )
    |> Repo.insert()
  end

  def generate(%Scope{phone: %Phone{id: phone_id}} = scope, %{"name" => name}) do
    password_required = false

    %SharedLink{}
    |> SharedLink.generate_changeset(
      %{
        "phone_id" => phone_id,
        "name" => name,
        "link_id" => generate_link_id(scope),
        "password_required" => password_required
      },
      password_required: password_required
    )
    |> Repo.insert()
  end

  def enable_password(%Scope{phone: %Phone{}} = scope, %{
        "id" => id,
        "password" => password
      }) do
    with {:ok, shared_link} <- find_for(scope, id: id) do
      shared_link
      |> SharedLink.enable_password_changeset(%{
        "password_required" => true,
        "password" => password
      })
      |> Repo.update()
    else
      {:error, :not_found} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  def disable_password(%Scope{phone: %Phone{}} = scope, %{"id" => id}) do
    with {:ok, shared_link} <- find_for(scope, id: id) do
      shared_link
      |> SharedLink.disable_password_changeset(%{
        "password_required" => false,
        "hashed_password" => nil
      })
      |> Repo.update()
    else
      {:error, :not_found} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  def remove(%Scope{phone: %Phone{id: phone_id}}, id) do
    with {:ok, shared_link} <- find_for(%Scope{phone: %Phone{id: phone_id}}, id: id),
         {:ok, shared_link} <- Repo.delete(shared_link) do
      {:ok, shared_link}
    else
      {:error, :not_found} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  def find_for(%Scope{phone: %Phone{id: phone_id}}, id: id) do
    from(s in SharedLink, where: s.id == ^id and s.phone_id == ^phone_id)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      shared_link ->
        {:ok, shared_link}
    end
  end

  defp generate_link_id(%Scope{phone: %Phone{id: phone_id}}) do
    :crypto.hash(:sha256, "#{phone_id}" <> Ecto.UUID.generate()) |> Base.encode16()
  end
end
