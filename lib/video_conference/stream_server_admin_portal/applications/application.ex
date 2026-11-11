defmodule VideoConference.StreamServerAdminPortal.Applications.Application do
  @moduledoc """
  A third-party application that integrates with the stream server API.

  Applications own API keys (`api_keys`) that authenticate their calls to
  the stream server REST API.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias VideoConference.StreamServerAdminPortal.Applications.{ApiKey, StreamServerPublicKey}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "applications" do
    field :name, :string
    field :description, :string
    field :enabled, :boolean, default: true
    field :lock_version, :integer, default: 1

    has_many :api_keys, ApiKey
    has_many :stream_server_public_keys, StreamServerPublicKey

    timestamps()
  end

  @doc """
  An application changeset.

  Requires a `name`. `description` and `enabled` are optional.
  """
  def changeset(%__MODULE__{} = application, attrs) do
    application
    |> cast(attrs, [:name, :description, :enabled])
    |> validate_required([:name])
  end

  @doc """
  A changeset for renaming an application. Keeps the required-name
  validation.
  """
  def name_changeset(%__MODULE__{} = application, attrs) do
    application
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> optimistic_lock(:lock_version)
  end

  @doc """
  A changeset for editing an application's description.
  """
  def description_changeset(%__MODULE__{} = application, attrs) do
    application
    |> cast(attrs, [:description])
    |> optimistic_lock(:lock_version)
  end

  @doc """
  A changeset for toggling an application's enabled flag.
  """
  def enabled_changeset(%__MODULE__{} = application, attrs) do
    application
    |> cast(attrs, [:enabled])
    |> validate_required([:enabled])
    |> optimistic_lock(:lock_version)
  end
end
