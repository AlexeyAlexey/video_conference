defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.CreateStreamServerApiKeys do
  use Ecto.Migration

  def change do
    create table(:stream_server_api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :stream_server_id,
          references(:stream_servers, type: :binary_id, on_delete: :delete_all),
          null: false

      add :name, :string, null: false
      add :prefix, :string, null: false
      add :hashed_api_key, :string, null: false
      add :description, :text
      add :enabled, :boolean, default: true, null: false
      add :lock_version, :integer, default: 1, null: false

      timestamps()
    end

    create unique_index(:stream_server_api_keys, [:prefix])
    create unique_index(:stream_server_api_keys, [:stream_server_id, :hashed_api_key])
  end
end
