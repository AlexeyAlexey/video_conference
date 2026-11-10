defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.AddLockVersionToApplications do
  use Ecto.Migration

  def change do
    alter table(:applications) do
      add :lock_version, :integer, default: 1, null: false
    end
  end
end
