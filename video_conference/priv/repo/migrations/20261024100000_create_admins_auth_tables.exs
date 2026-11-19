defmodule VideoConference.Repo.Migrations.CreateAdminsAuthTables do
  use Ecto.Migration

  def change do
    create table(:admins) do
      add :email, :string, null: false
      add :hashed_password, :string

      timestamps()
    end

    create unique_index(:admins, [:email])

    create table(:admin_tokens) do
      add :admin_id, references(:admins, on_delete: :delete_all), null: false
      add :token, :binary, null: false, size: 32
      add :context, :string, null: false
      add :authenticated_at, :utc_datetime

      timestamps(updated_at: false)
    end

    create index(:admin_tokens, [:admin_id])
    create unique_index(:admin_tokens, [:context, :token])
  end
end
