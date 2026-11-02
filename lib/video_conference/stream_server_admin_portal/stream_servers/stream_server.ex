defmodule VideoConference.StreamServerAdminPortal.StreamServers.StreamServer do
  @moduledoc """
  A physical stream server registered in the stream server admin portal.

  `settings` is a free-form map for future keys. `cert_hash` is a dedicated
  column carrying the server's TLS certificate hash for servers that use a
  self-signed certificate. Servers are assigned to applications through the
  `applications` many-to-many association.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias VideoConference.StreamServerAdminPortal.Applications.Application
  alias VideoConference.StreamServerAdminPortal.Repo
  alias VideoConference.StreamServerAdminPortal.StreamServers.ApplicationStreamServer
  alias VideoConference.StreamServers.Countries

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "stream_servers" do
    field :name, :string
    field :description, :string
    field :host, :string
    field :country, :string
    field :settings, :map, default: %{}
    field :cert_hash, :string

    many_to_many :applications, Application,
      join_through: ApplicationStreamServer,
      join_keys: [stream_server_id: :id, application_id: :id],
      on_replace: :delete

    timestamps()
  end

  @doc """
  A stream server changeset.

  Requires a unique `name` and restricts `country` to the supported ISO
  alpha-2 codes in `Countries`. `description`, `host`, `settings`, and
  `cert_hash` are optional.
  """
  def changeset(%__MODULE__{} = stream_server, attrs) do
    stream_server
    |> cast(attrs, [:name, :description, :host, :country, :settings, :cert_hash])
    |> validate_required([:name])
    |> validate_inclusion(:country, Countries.codes())
    |> unsafe_validate_unique(:name, Repo)
    |> unique_constraint(:name)
  end
end
