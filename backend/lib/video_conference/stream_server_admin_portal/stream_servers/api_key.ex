defmodule VideoConference.StreamServerAdminPortal.StreamServers.ApiKey do
  @moduledoc """
  An API key credential belonging to a stream server.

  `hashed_api_key` persists the bcrypt hash of the generated secret. The
  virtual `plaintext_key` carries the secret back to the caller at creation
  time only — it is never stored, and the key's secret is immutable after
  creation (the changeset never casts it). `prefix` stores the secret's
  `"ssak_" <> prefix_id` lookup prefix so a presented secret can be
  matched to this record; it is unique. Key names are deliberately not unique; only
  the hashed secret is unique within one stream server.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias VideoConference.StreamServerAdminPortal.StreamServers.StreamServer

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "stream_server_api_keys" do
    field :name, :string
    field :hashed_api_key, :string, redact: true
    field :prefix, :string
    field :description, :string
    field :enabled, :boolean, default: true
    field :lock_version, :integer, default: 1

    field :plaintext_key, :string, virtual: true, redact: true

    belongs_to :stream_server, StreamServer

    timestamps()
  end

  @doc """
  A stream server API key changeset.

  Requires `name` and `stream_server_id`. The name is not unique; only
  the hashed secret is unique within its stream server.
  """
  def changeset(%__MODULE__{} = api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :description, :enabled, :stream_server_id])
    |> validate_required([:name, :stream_server_id])
    |> unique_constraint(:hashed_api_key,
      name: :stream_server_api_keys_stream_server_id_hashed_api_key_index
    )
    |> unique_constraint(:prefix)
    |> assoc_constraint(:stream_server)
  end

  @doc """
  A changeset for renaming a stream server API key.
  """
  def name_changeset(%__MODULE__{} = api_key, attrs) do
    api_key
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> optimistic_lock(:lock_version)
  end

  @doc """
  A changeset for editing a stream server API key's description.
  """
  def description_changeset(%__MODULE__{} = api_key, attrs) do
    api_key
    |> cast(attrs, [:description])
    |> optimistic_lock(:lock_version)
  end

  @doc """
  A changeset for toggling a stream server API key's enabled flag.
  """
  def enabled_changeset(%__MODULE__{} = api_key, attrs) do
    api_key
    |> cast(attrs, [:enabled])
    |> validate_required([:enabled])
    |> optimistic_lock(:lock_version)
  end
end
