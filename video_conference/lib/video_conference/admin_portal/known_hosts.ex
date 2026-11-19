defmodule VideoConference.AdminPortal.KnownHosts do
  @moduledoc """
  The AdminPortal KnownHosts context.

  Manages the directory of peer application instances ("known hosts").
  Exactly one row is the `current_host`, seeded by a migration: it cannot
  be deleted or disabled, and no other row can take the flag over.
  """

  import Ecto.Query, warn: false
  alias VideoConference.Repo

  alias VideoConference.AdminPortal.KnownHosts.KnownHost

  @doc """
  Returns all known hosts, the current host first, then ordered by name.
  """
  def list_known_hosts do
    Repo.all(from k in KnownHost, order_by: [desc: k.current_host, asc: k.name])
  end

  @doc """
  Gets a single known host.

  Raises `Ecto.NoResultsError` if the known host does not exist.
  """
  def get_known_host!(id), do: Repo.get!(KnownHost, id)

  @doc """
  Creates a known host.
  """
  def create_known_host(attrs \\ %{}) do
    %KnownHost{}
    |> KnownHost.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a known host.

  The current host cannot lose its `current_host` flag or be disabled,
  and `current_host` cannot be set on a second row; such updates return
  an error changeset.
  """
  def update_known_host(%KnownHost{} = known_host, attrs) do
    known_host
    |> KnownHost.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a known host.

  Returns an error changeset for the current host, which cannot be
  removed.
  """
  def delete_known_host(%KnownHost{current_host: true} = known_host) do
    changeset =
      known_host
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.add_error(:current_host, "the current host cannot be deleted")
      |> Map.put(:action, :delete)

    {:error, changeset}
  end

  def delete_known_host(%KnownHost{} = known_host) do
    Repo.delete(known_host)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking known host changes.
  """
  def change_known_host(%KnownHost{} = known_host, attrs \\ %{}) do
    KnownHost.changeset(known_host, attrs)
  end
end
