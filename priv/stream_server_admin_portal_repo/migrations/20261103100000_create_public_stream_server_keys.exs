defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.CreatePublicStreamServerKeys do
  use Ecto.Migration

  def change do
    create table(:public_stream_server_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :application_id,
          references(:applications, type: :binary_id, on_delete: :delete_all),
          null: false

      add :name, :string
      add :public_key, :text, null: false
      add :disabled, :boolean, default: false, null: false
      add :description, :text

      timestamps()
    end
  end
end
