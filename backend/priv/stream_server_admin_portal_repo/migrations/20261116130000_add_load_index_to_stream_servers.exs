defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.AddLoadIndexToStreamServers do
  use Ecto.Migration

  def change do
    create index(:stream_servers, [:load])
  end
end
