defmodule VideoConference.Repo.Migrations.SeedDefaultAdmin do
  use Ecto.Migration

  import Ecto.Query

  def up do
    now = DateTime.utc_now(:second)

    repo().insert_all(
      "admins",
      [
        [
          email: "admin@admin.com",
          hashed_password: Bcrypt.hash_pwd_salt("admin"),
          inserted_at: now,
          updated_at: now
        ]
      ],
      on_conflict: :nothing
    )
  end

  def down do
    repo().delete_all(from(a in "admins", where: a.email == "admin@admin.com"))
  end
end
