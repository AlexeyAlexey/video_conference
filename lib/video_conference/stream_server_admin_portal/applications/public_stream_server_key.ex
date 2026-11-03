defmodule VideoConference.StreamServerAdminPortal.Applications.PublicStreamServerKey do
  @moduledoc """
  A public stream server key belonging to an application.

  The portal stores only public key material the admin pastes in — there is
  no private key and no `public_key_id` column: the record's own UUID
  primary key serves as the public key id that a stream server later uses
  to pick the public key verifying the application's signed JWT.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias VideoConference.StreamServerAdminPortal.Applications.Application

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "public_stream_server_keys" do
    field :name, :string
    field :public_key, :string
    field :disabled, :boolean, default: false
    field :description, :string

    belongs_to :application, Application

    timestamps()
  end

  @doc """
  A public stream server key changeset.

  Requires `public_key` and `application_id`. `name` is optional and not
  unique — the record's UUID is the public key id that identifies it.
  """
  def changeset(%__MODULE__{} = key, attrs) do
    key
    |> cast(attrs, [:name, :public_key, :disabled, :description, :application_id])
    |> validate_required([:public_key, :application_id])
    |> assoc_constraint(:application)
  end
end
