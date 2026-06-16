defmodule VideoConference.Repo.Migrations.CreateKnownHosts do
  use Ecto.Migration

  def change do
    create table(:known_hosts) do
      add :name, :string
      add :settings, :map

      timestamps()
    end
  end
end
