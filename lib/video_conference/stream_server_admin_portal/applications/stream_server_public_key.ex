defmodule VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKey do
  @moduledoc """
  A stream server public key belonging to an application.

  The portal stores only public key material the admin pastes in — there is
  no private key and no `key_id` column: the record's own UUID
  primary key serves as the key id that a stream server later uses
  to pick the public key verifying the application's signed JWT.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias VideoConference.StreamServerAdminPortal.Applications.Application

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "stream_server_public_keys" do
    field :name, :string
    field :key, :string
    field :enabled, :boolean, default: true
    field :description, :string

    belongs_to :application, Application

    timestamps()
  end

  @doc """
  A stream server public key changeset.

  Requires `key` and `application_id`. `name` is optional and not
  unique — the record's UUID is the key id that identifies it.
  """
  def changeset(%__MODULE__{} = key, attrs) do
    key
    |> cast(attrs, [:name, :key, :enabled, :description, :application_id])
    |> validate_required([:key, :application_id])
    |> assoc_constraint(:application)
  end
end
