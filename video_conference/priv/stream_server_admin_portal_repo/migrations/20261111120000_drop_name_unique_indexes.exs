defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.DropNameUniqueIndexes do
  use Ecto.Migration

  def up do
    drop index(:applications, [:name], name: :applications_name_index)
    drop index(:stream_servers, [:name], name: :stream_servers_name_index)
  end

  def down do
    create unique_index(:applications, [:name])
    create unique_index(:stream_servers, [:name])
  end
end
