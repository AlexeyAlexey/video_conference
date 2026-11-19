defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.CreateStreamServers do
  use Ecto.Migration

  def change do
    create table(:stream_servers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :host, :string
      add :country, :string
      add :settings, :map
      add :cert_hash, :string

      timestamps()
    end

    create unique_index(:stream_servers, [:name])

    create table(:application_stream_servers, primary_key: false) do
      add :application_id,
          references(:applications, type: :binary_id, on_delete: :delete_all),
          null: false

      add :stream_server_id,
          references(:stream_servers, type: :binary_id, on_delete: :delete_all),
          null: false
    end

    create unique_index(:application_stream_servers, [:application_id, :stream_server_id])
  end
end
