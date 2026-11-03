defmodule VideoConference.StreamServerAdminPortal.Applications do
  @moduledoc """
  The StreamServerAdminPortal Applications context.

  Manages third-party applications that integrate with the stream server,
  the API keys that authenticate them, and the public stream server keys
  that verify their signed JWTs. API key secrets are generated at
  creation, returned once as `plaintext_key`, and persisted only as a
  bcrypt hash.
  """

  import Ecto.Query, warn: false
  alias VideoConference.StreamServerAdminPortal.Repo

  alias VideoConference.StreamServerAdminPortal.Applications.{
    ApiKey,
    Application,
    PublicStreamServerKey
  }

  ## Applications

  @doc """
  Returns all applications, ordered by name.
  """
  def list_applications do
    Repo.all(from a in Application, order_by: [asc: a.name])
  end

  @doc """
  Returns all applications ordered by name, each with its API keys
  preloaded (ordered by name). Used by the grouped API keys portal page.
  """
  def list_applications_with_api_keys do
    keys = from k in ApiKey, order_by: [asc: k.name]

    Repo.all(
      from a in Application,
        order_by: [asc: a.name],
        preload: [api_keys: ^keys]
    )
  end

  @doc """
  Returns all applications ordered by name, each with its public stream
  server keys preloaded (ordered by name). Used by the grouped public
  keys portal page.

  Options:

    * `:application_id` — limits the list to the given application.
      `nil` or `""` lists every application.
  """
  def list_applications_with_public_keys(opts \\ []) do
    keys = from k in PublicStreamServerKey, order_by: [asc: k.name]

    Application
    |> filter_by_id(Keyword.get(opts, :application_id))
    |> order_by([a], asc: a.name)
    |> preload(public_stream_server_keys: ^keys)
    |> Repo.all()
  end

  defp filter_by_id(query, application_id) when application_id in [nil, ""], do: query
  defp filter_by_id(query, application_id), do: from(a in query, where: a.id == ^application_id)

  @doc """
  Gets a single application.

  Raises `Ecto.NoResultsError` if the application does not exist.
  """
  def get_application!(id), do: Repo.get!(Application, id)

  @doc """
  Creates an application.
  """
  def create_application(attrs \\ %{}) do
    %Application{}
    |> Application.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an application.
  """
  def update_application(%Application{} = application, attrs) do
    application
    |> Application.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an application. Its API keys and public stream server keys are
  removed by the database's `on_delete: :delete_all` foreign keys.
  """
  def delete_application(%Application{} = application) do
    Repo.delete(application)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking application changes.
  """
  def change_application(%Application{} = application, attrs \\ %{}) do
    Application.changeset(application, attrs)
  end

  ## API keys

  @doc """
  Returns the API keys of the given application, ordered by name.
  """
  def list_api_keys(%Application{} = application) do
    Repo.all(
      from k in ApiKey,
        where: k.application_id == ^application.id,
        order_by: [asc: k.name]
    )
  end

  @doc """
  Gets a single API key.

  Raises `Ecto.NoResultsError` if the key does not exist.
  """
  def get_api_key!(id), do: Repo.get!(ApiKey, id)

  @doc """
  Creates an API key with a freshly generated secret.

  Returns `{:ok, api_key}` where `api_key.plaintext_key` holds the
  generated secret — the only time it is available. Only the bcrypt hash
  is persisted.
  """
  def create_api_key(attrs \\ %{}) do
    secret = generate_api_key_secret()

    %ApiKey{}
    |> ApiKey.changeset(attrs)
    |> Ecto.Changeset.put_change(:hashed_api_key, Bcrypt.hash_pwd_salt(secret))
    |> Repo.insert()
    |> case do
      {:ok, api_key} -> {:ok, %{api_key | plaintext_key: secret}}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Updates an API key's name, description, enabled flag, or parent
  application. The stored secret hash is never touched.
  """
  def update_api_key(%ApiKey{} = api_key, attrs) do
    api_key
    |> ApiKey.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an API key.
  """
  def delete_api_key(%ApiKey{} = api_key) do
    Repo.delete(api_key)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking API key changes.
  """
  def change_api_key(%ApiKey{} = api_key, attrs \\ %{}) do
    ApiKey.changeset(api_key, attrs)
  end

  @doc """
  Generates a random API key secret prefixed with `ssak_` so leaked keys
  are recognizable in logs and config scans.
  """
  def generate_api_key_secret do
    "ssak_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  end

  ## Public stream server keys

  @doc """
  Gets a single public stream server key.

  Raises `Ecto.NoResultsError` if the key does not exist.
  """
  def get_public_stream_server_key!(id), do: Repo.get!(PublicStreamServerKey, id)

  @doc """
  Creates a public stream server key holding existing public key
  material. The record's generated UUID serves as its public key id.
  """
  def create_public_stream_server_key(attrs \\ %{}) do
    %PublicStreamServerKey{}
    |> PublicStreamServerKey.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a public stream server key's name, public key material,
  disabled flag, description, or parent application.
  """
  def update_public_stream_server_key(%PublicStreamServerKey{} = key, attrs) do
    key
    |> PublicStreamServerKey.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a public stream server key.
  """
  def delete_public_stream_server_key(%PublicStreamServerKey{} = key) do
    Repo.delete(key)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking public stream server key
  changes.
  """
  def change_public_stream_server_key(%PublicStreamServerKey{} = key, attrs \\ %{}) do
    PublicStreamServerKey.changeset(key, attrs)
  end
end
