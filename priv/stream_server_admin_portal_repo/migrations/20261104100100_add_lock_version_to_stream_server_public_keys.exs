defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.AddLockVersionToStreamServerPublicKeys do
  use Ecto.Migration

  def change do
    alter table(:stream_server_public_keys) do
      add :lock_version, :integer, default: 1, null: false
    end
  end
end
