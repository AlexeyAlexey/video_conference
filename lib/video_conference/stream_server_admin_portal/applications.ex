defmodule VideoConference.StreamServerAdminPortal.Applications do
  @moduledoc """
  The StreamServerAdminPortal Applications context.

  Manages third-party applications that integrate with the stream server,
  the API keys that authenticate them, and the stream server public keys
  that verify their signed JWTs. API key secrets are generated at
  creation, returned once as `plaintext_key`, and persisted only as a
  bcrypt hash.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias VideoConference.StreamServerAdminPortal.EventStore
  alias VideoConference.StreamServerAdminPortal.Repo

  alias VideoConference.StreamServerAdminPortal.Applications.{
    ApiKey,
    Application,
    ApplicationDescriptionWasUpdated,
    ApplicationWasAdded,
    ApplicationWasDisabled,
    ApplicationWasEnabled,
    ApplicationWasRemoved,
    ApplicationWasRenamed,
    StreamServerPublicKey,
    StreamServerPublicKeyAddedEvent
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
  def list_applications_with_stream_server_public_keys(opts \\ []) do
    keys = from k in StreamServerPublicKey, order_by: [asc: k.name]

    Application
    |> filter_by_id(Keyword.get(opts, :application_id))
    |> order_by([a], asc: a.name)
    |> preload(stream_server_public_keys: ^keys)
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

  Commits the record and an `ApplicationWasAdded` event on the
  application's stream in the same transaction.
  """
  def create_application(attrs \\ %{}) do
    Multi.new()
    |> Multi.insert(:application, Application.changeset(%Application{}, attrs))
    |> Multi.merge(fn %{application: application} ->
      EventStore.append([ApplicationWasAdded.new(application)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Renames an application. The name must remain unique across
  applications.
  """
  def rename_application(id, name) do
    application = get_application!(id)

    Multi.new()
    |> Multi.update(
      :application,
      Application.name_changeset(application, %{"name" => name}),
      stale_error_field: :lock_version
    )
    |> Multi.merge(fn %{application: application} ->
      EventStore.append([ApplicationWasRenamed.new(application)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Updates an application's description.
  """
  def edit_application_description(id, description) do
    application = get_application!(id)

    Multi.new()
    |> Multi.update(
      :application,
      Application.description_changeset(application, %{"description" => description}),
      stale_error_field: :lock_version
    )
    |> Multi.merge(fn %{application: application} ->
      EventStore.append([ApplicationDescriptionWasUpdated.new(application)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Enables an application.
  """
  def enable_application(id) do
    application = get_application!(id)

    Multi.new()
    |> Multi.update(
      :application,
      Application.enabled_changeset(application, %{"enabled" => true}),
      stale_error_field: :lock_version
    )
    |> Multi.merge(fn %{application: application} ->
      EventStore.append([ApplicationWasEnabled.new(application)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Disables an application.
  """
  def disable_application(id) do
    application = get_application!(id)

    Multi.new()
    |> Multi.update(
      :application,
      Application.enabled_changeset(application, %{"enabled" => false}),
      stale_error_field: :lock_version
    )
    |> Multi.merge(fn %{application: application} ->
      EventStore.append([ApplicationWasDisabled.new(application)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Removes an application. Its API keys and stream server public keys are
  removed by the database's `on_delete: :delete_all` foreign keys.

  Commits the delete and an `ApplicationWasRemoved` event on the
  application's stream in the same transaction.
  """
  def remove_application(%Application{} = application) do
    changeset =
      application
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.optimistic_lock(:lock_version)

    Multi.new()
    |> Multi.delete(:application, changeset, stale_error_field: :lock_version)
    |> Multi.merge(fn _changes ->
      EventStore.append([ApplicationWasRemoved.new(application)])
    end)
    |> Repo.transaction()
    |> transaction_result()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking application changes.
  """
  def change_application(%Application{} = application, attrs \\ %{}) do
    Application.changeset(application, attrs)
  end

  defp transaction_result({:ok, %{application: application}}), do: {:ok, application}

  defp transaction_result({:error, _operation, %Ecto.Changeset{} = changeset, _changes}),
    do: {:error, changeset}

  defp transaction_result({:error, _operation, error, _changes}), do: {:error, error}

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

  ## Stream server public keys

  @doc """
  Gets a single stream server public key.

  Raises `Ecto.NoResultsError` if the key does not exist.
  """
  def get_stream_server_public_key!(id), do: Repo.get!(StreamServerPublicKey, id)

  @doc """
  Creates a stream server public key holding existing public key
  material. The record's generated UUID serves as its key id.
  """
  def create_stream_server_public_key(attrs \\ %{}) do
    Multi.new()
    |> Multi.insert(
      :stream_server_public_key,
      StreamServerPublicKey.changeset(%StreamServerPublicKey{}, attrs)
    )
    |> Multi.merge(fn %{stream_server_public_key: key} ->
      EventStore.append([StreamServerPublicKeyAddedEvent.new(key)])
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{stream_server_public_key: key}} -> {:ok, key}
      {:error, _operation, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
      {:error, _operation, error, _changes} -> {:error, error}
    end
  end

  @doc """
  Renames a stream server public key. The public key material is
  immutable and cannot be changed through this function.
  """
  def rename_stream_server_public_key(id, name) do
    id
    |> get_stream_server_public_key!()
    |> StreamServerPublicKey.name_changeset(%{"name" => name})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Updates a stream server public key's description. The public key
  material is immutable and cannot be changed through this function.
  """
  def edit_stream_server_public_key_description(id, description) do
    id
    |> get_stream_server_public_key!()
    |> StreamServerPublicKey.description_changeset(%{"description" => description})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Moves a stream server public key to another application. The public
  key material is immutable and cannot be changed through this
  function.
  """
  def switch_stream_server_public_key_application(id, application_id) do
    id
    |> get_stream_server_public_key!()
    |> StreamServerPublicKey.application_changeset(%{"application_id" => application_id})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Enables a stream server public key.
  """
  def enable_stream_server_public_key(id) do
    id
    |> get_stream_server_public_key!()
    |> StreamServerPublicKey.enabled_changeset(%{"enabled" => true})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Disables a stream server public key.
  """
  def disable_stream_server_public_key(id) do
    id
    |> get_stream_server_public_key!()
    |> StreamServerPublicKey.enabled_changeset(%{"enabled" => false})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Deletes a stream server public key.
  """
  def delete_stream_server_public_key(%StreamServerPublicKey{} = key) do
    key
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.optimistic_lock(:lock_version)
    |> Repo.delete(stale_error_field: :lock_version)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stream server public key
  changes.
  """
  def change_stream_server_public_key(%StreamServerPublicKey{} = key, attrs \\ %{}) do
    StreamServerPublicKey.changeset(key, attrs)
  end
end
