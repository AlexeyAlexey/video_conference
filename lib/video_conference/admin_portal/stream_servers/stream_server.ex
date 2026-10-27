defmodule VideoConference.AdminPortal.StreamServers.StreamServer do
  @moduledoc """
  An HTTP/3 stream server available to carry participant streams.

  `settings` is a free-form map that currently carries `cert_hash`; the
  virtual `cert_hash` field gives forms a first-class input that the
  changeset folds into `settings["cert_hash"]`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias VideoConference.AdminPortal.StreamServers.Countries

  schema "stream_servers" do
    field :name, :string
    field :description, :string
    field :host, :string
    field :country, :string
    field :settings, :map, default: %{}
    field :third_party, :boolean, default: false

    field :cert_hash, :string, virtual: true

    timestamps()
  end

  @doc """
  A stream server changeset.

  Requires a unique `name` and restricts `country` to the supported ISO
  alpha-2 codes in `Countries`. A blank `cert_hash` removes
  `settings["cert_hash"]`, any other value sets it; other settings keys
  are preserved.
  """
  def changeset(%__MODULE__{} = stream_server, attrs) do
    stream_server
    |> populate_cert_hash()
    |> cast(attrs, [
      :name,
      :description,
      :host,
      :country,
      :settings,
      :third_party,
      :cert_hash
    ])
    |> validate_required([:name])
    |> validate_inclusion(:country, Countries.codes())
    |> put_cert_hash()
    |> unsafe_validate_unique(:name, VideoConference.Repo)
    |> unique_constraint(:name)
  end

  # Populates the virtual field from persisted settings so forms render
  # the stored certificate hash.
  defp populate_cert_hash(%__MODULE__{} = stream_server) do
    %{
      stream_server
      | cert_hash: Map.get(stream_server.settings || %{}, "cert_hash")
    }
  end

  defp put_cert_hash(changeset) do
    case fetch_change(changeset, :cert_hash) do
      {:ok, cert_hash} ->
        settings =
          (get_field(changeset, :settings) || %{})
          |> then(fn settings ->
            if cert_hash in [nil, ""],
              do: Map.delete(settings, "cert_hash"),
              else: Map.put(settings, "cert_hash", cert_hash)
          end)

        put_change(changeset, :settings, settings)

      :error ->
        changeset
    end
  end
end
