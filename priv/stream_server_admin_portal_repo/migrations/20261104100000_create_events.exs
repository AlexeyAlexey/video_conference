defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :seq, :integer, primary_key: true
      add :stream_id, :string, null: false
      add :version, :integer, null: false
      add :event_type, :string, null: false
      add :payload, :binary, null: false
      add :added_at, :utc_datetime_usec, null: false
    end

    create unique_index(:events, [:stream_id, :version])
  end
end
