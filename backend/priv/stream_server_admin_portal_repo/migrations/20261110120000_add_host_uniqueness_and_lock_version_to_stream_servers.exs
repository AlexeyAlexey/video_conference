defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.AddHostUniquenessAndLockVersionToStreamServers do
  use Ecto.Migration

  def change do
    alter table(:stream_servers) do
      add :lock_version, :integer, default: 1, null: false
    end

    create unique_index(:stream_servers, [:host])
  end
end
