defmodule VideoConference.TelephoneSwitchboard.SharedLinks do
  import Ecto.Query, warn: false
  alias VideoConference.Repo

  alias VideoConference.TelephoneSwitchboard.SharedLinks.SharedLink
  alias VideoConference.Accounts.Scope
  alias VideoConference.Accounts.Phone

  alias VideoConference.TelephoneSwitchboard.SharedLinks
  alias VideoConference.TelephoneSwitchboard.ConnectionCredentials

  def connection_credentials(
        link_id: link_id,
        password: password
      )
      when is_binary(link_id) and is_binary(password) do
    with {:ok, shared_link} <- SharedLinks.one_by(link_id: link_id),
         :ok <- check_password_if_required(shared_link, password) do
      {:ok, provide_credentials(link_id: link_id)}
    end
  end

  def connection_credentials(link_id: link_id) when is_binary(link_id) do
    with {:ok, shared_link} <- SharedLinks.one_by(link_id: link_id),
         :ok <- check_password_if_required(shared_link) do
      {:ok, provide_credentials(link_id: link_id)}
    end
  end

  def one_by(link_id: link_id) do
    Repo.one(from s in SharedLink, where: s.link_id == ^link_id)
    |> case do
      nil -> {:error, :not_found}
      shared_link -> {:ok, shared_link}
    end
  end

  def one_by(%Scope{phone: %Phone{id: phone_id}}, link_id: link_id) do
    Repo.one(from s in SharedLink, where: s.phone_id == ^phone_id and s.link_id == ^link_id)
    |> case do
      nil -> {:error, :not_found}
      shared_link -> {:ok, shared_link}
    end
  end

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

  def rename(%Scope{phone: %Phone{}} = scope, %{
        "id" => id,
        "name" => name
      }) do
    with {:ok, shared_link} <- find_for(scope, id: id) do
      shared_link
      |> SharedLink.rename_changeset(%{
        "name" => name
      })
      |> Repo.update()
    else
      {:error, :not_found} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
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

  defp provide_credentials(link_id: link_id) do
    # TODO add logic to manage participant_id
    # it should be uniq in shared link (link id) scope
    params = %{
      "conference_id" => link_id,
      "participant_id" => System.unique_integer([:positive, :monotonic]),
      "host" => "local"
    }

    ConnectionCredentials.for("video", "conference", params)
    |> Map.merge(ConnectionCredentials.for("audio", "conference", params))
    |> Map.put("participant_id", params["participant_id"])
  end

  defp generate_link_id(%Scope{phone: %Phone{id: phone_id}}) do
    :crypto.hash(:sha256, "#{phone_id}" <> Ecto.UUID.generate()) |> Base.encode16()
  end

  defp check_password_if_required(%SharedLink{} = shared_link, password)
       when is_binary(password) do
    if SharedLink.password_required(shared_link) do
      if SharedLink.valid_password?(shared_link, password),
        do: :ok,
        else: {:error, "invalid password"}
    else
      :ok
    end
  end

  defp check_password_if_required(%SharedLink{} = shared_link) do
    if SharedLink.password_required(shared_link) do
      {:error, "requires password"}
    else
      :ok
    end
  end
end
