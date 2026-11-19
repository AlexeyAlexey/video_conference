defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.CreateStreamServerPublicKeys do
  use Ecto.Migration

  def change do
    create table(:stream_server_public_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :application_id,
          references(:applications, type: :binary_id, on_delete: :delete_all),
          null: false

      add :name, :string
      add :key, :text, null: false
      add :enabled, :boolean, default: true, null: false
      add :description, :text

      timestamps()
    end
  end
end
