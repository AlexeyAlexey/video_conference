defmodule VideoConference.AdminPortal.KnownHosts.KnownHost do
  @moduledoc """
  A peer application instance this host knows about.

  Exactly one row is the `current_host` — this instance's own identity,
  seeded by a migration. The changeset guards that row: it cannot lose its
  `current_host` flag and cannot be disabled, and no other row can take
  the flag over.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "known_hosts" do
    field :name, :string
    field :name_alias, :string
    field :description, :string
    field :host, :string
    field :current_host, :boolean, default: false
    field :enabled, :boolean, default: true
    field :settings, :map, default: %{}

    timestamps()
  end

  @doc """
  A known host changeset.

  Requires a unique `name`. On the current host row, rejects changes that
  would clear `current_host` or set `enabled` to false; on any other row,
  rejects setting `current_host`.
  """
  def changeset(%__MODULE__{} = known_host, attrs) do
    known_host
    |> cast(attrs, [:name, :name_alias, :description, :host, :current_host, :enabled, :settings])
    |> validate_required([:name])
    |> unsafe_validate_unique(:name, VideoConference.Repo)
    |> unique_constraint(:name)
    |> protect_current_host()
  end

  defp protect_current_host(changeset) do
    if changeset.data.current_host do
      changeset
      |> validate_change(:current_host, fn :current_host, current_host ->
        if current_host, do: [], else: [current_host: "cannot be unset on the current host"]
      end)
      |> validate_change(:enabled, fn :enabled, enabled ->
        if enabled, do: [], else: [enabled: "the current host cannot be disabled"]
      end)
    else
      validate_change(changeset, :current_host, fn :current_host, current_host ->
        if current_host,
          do: [current_host: "another host is already the current host"],
          else: []
      end)
    end
  end
end
