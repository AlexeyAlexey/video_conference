defmodule VideoConference.Repo.Migrations.CreatePublicStreamServerKeys do
  use Ecto.Migration

  def change do
    create table(:public_stream_server_keys) do
      add :name, :string, null: false
      add :public_key_id, :string
      add :public_key, :text, null: false
      add :private_key, :text, null: false
      add :stream_server_id, references(:stream_servers, on_delete: :delete_all), null: false
      add :disabled, :boolean, default: false, null: false
      add :description, :text

      timestamps()
    end

    create unique_index(:public_stream_server_keys, [:stream_server_id, :name])
  end
end
