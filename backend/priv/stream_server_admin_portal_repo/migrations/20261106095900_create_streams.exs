defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.CreateStreams do
  use Ecto.Migration

  def up do
    create table(:streams, primary_key: false) do
      add :id, :integer, primary_key: true
      add :stream_id, :string, null: false
      add :version, :bigint, default: 0, null: false
      add :created_at, :utc_datetime_usec, null: false
      add :deleted_at, :utc_datetime_usec
    end

    create unique_index(:streams, [:stream_id])

    flush()

    repo().insert_all("streams", [
      [id: 0, stream_id: "$all", version: 0, created_at: DateTime.utc_now()]
    ])
  end

  def down do
    drop table(:streams)
  end
end
