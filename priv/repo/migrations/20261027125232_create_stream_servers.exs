defmodule VideoConference.Repo.Migrations.CreateStreamServers do
  use Ecto.Migration

  def change do
    create table(:stream_servers) do
      add :name, :string, null: false
      add :description, :text
      add :host, :string
      add :country, :string
      add :settings, :map
      add :third_party, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:stream_servers, [:name])
  end
end
