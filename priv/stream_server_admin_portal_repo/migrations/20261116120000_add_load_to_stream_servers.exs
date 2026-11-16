defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.AddLoadToStreamServers do
  use Ecto.Migration

  def change do
    alter table(:stream_servers) do
      add :load, :integer,
        null: false,
        default: 0,
        check: %{
          name: :load_must_be_between_0_and_100,
          expr: "load >= 0 AND load <= 100"
        }
    end
  end
end
