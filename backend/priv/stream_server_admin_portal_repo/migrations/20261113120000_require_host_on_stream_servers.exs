defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.RequireHostOnStreamServers do
  use Ecto.Migration

  @columns "id, name, description, host, country, settings, cert_hash, inserted_at, updated_at, lock_version"

  def up do
    execute("DELETE FROM stream_servers WHERE host IS NULL")

    preserving_join_rows(fn -> rebuild_stream_servers(null: false) end)
  end

  def down do
    preserving_join_rows(fn -> rebuild_stream_servers(null: true) end)
  end

  defp preserving_join_rows(fun) do
    execute("""
    CREATE TABLE application_stream_servers_backup AS
    SELECT application_id, stream_server_id FROM application_stream_servers
    """)

    drop(table(:application_stream_servers))

    fun.()

    create table(:application_stream_servers, primary_key: false) do
      add :application_id,
          references(:applications, type: :binary_id, on_delete: :delete_all),
          null: false

      add :stream_server_id,
          references(:stream_servers, type: :binary_id, on_delete: :delete_all),
          null: false
    end

    execute("""
    INSERT INTO application_stream_servers (application_id, stream_server_id)
    SELECT application_id, stream_server_id FROM application_stream_servers_backup
    """)

    drop(table(:application_stream_servers_backup))

    create(unique_index(:application_stream_servers, [:application_id, :stream_server_id]))
  end

  defp rebuild_stream_servers(host_opts) do
    create table(:stream_servers_new, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :host, :string, host_opts
      add :country, :string
      add :settings, :map
      add :cert_hash, :string
      timestamps()
      add :lock_version, :integer, default: 1, null: false
    end

    execute(
      "INSERT INTO stream_servers_new (#{@columns}) " <>
        "SELECT #{@columns} FROM stream_servers"
    )

    drop(table(:stream_servers))
    rename(table(:stream_servers_new), to: table(:stream_servers))

    create(unique_index(:stream_servers, [:host]))
  end
end
