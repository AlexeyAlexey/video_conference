defmodule VideoConference.Repo.Migrations.SeedCurrentKnownHost do
  use Ecto.Migration

  import Ecto.Query

  def up do
    now = DateTime.utc_now(:second)

    repo().insert_all(
      "known_hosts",
      [
        [
          name: "current host",
          current_host: 1,
          enabled: 1,
          inserted_at: now,
          updated_at: now
        ]
      ],
      on_conflict: :nothing
    )
  end

  def down do
    repo().delete_all(from(k in "known_hosts", where: k.current_host == 1))
  end
end
