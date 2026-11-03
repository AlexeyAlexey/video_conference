defmodule VideoConference.StreamServerAdminPortal.Applications.Application do
  @moduledoc """
  A third-party application that integrates with the stream server API.

  Applications own API keys (`api_keys`) that authenticate their calls to
  the stream server REST API.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias VideoConference.StreamServerAdminPortal.Applications.{ApiKey, StreamServerPublicKey}
  alias VideoConference.StreamServerAdminPortal.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "applications" do
    field :name, :string
    field :description, :string
    field :enabled, :boolean, default: true

    has_many :api_keys, ApiKey
    has_many :stream_server_public_keys, StreamServerPublicKey

    timestamps()
  end

  @doc """
  An application changeset.

  Requires a `name`, which must be unique across applications.
  `description` and `enabled` are optional.
  """
  def changeset(%__MODULE__{} = application, attrs) do
    application
    |> cast(attrs, [:name, :description, :enabled])
    |> validate_required([:name])
    |> unsafe_validate_unique(:name, Repo)
    |> unique_constraint(:name)
  end
end
