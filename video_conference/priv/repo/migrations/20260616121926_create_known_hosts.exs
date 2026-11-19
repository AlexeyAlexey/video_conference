defmodule VideoConference.Repo.Migrations.CreateKnownHosts do
  use Ecto.Migration

  def change do
    create table(:known_hosts) do
      add :name, :string, null: false
      add :name_alias, :string
      add :description, :text
      add :host, :string
      add :current_host, :boolean, default: false, null: false
      add :enabled, :boolean, default: true, null: false
      add :settings, :map

      timestamps()
    end

    create unique_index(:known_hosts, [:name])

    create unique_index(:known_hosts, [:current_host],
             where: "current_host",
             name: :known_hosts_single_current_host_index
           )
  end
end
