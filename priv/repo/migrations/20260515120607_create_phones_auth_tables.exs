defmodule VideoConference.Repo.Migrations.CreatePhonesAuthTables do
  use Ecto.Migration

  def change do
    create table(:phones) do
      add :phone, :integer, null: false
      add :hashed_password, :string
      add :confirmed_at, :naive_datetime

      timestamps()
    end

    create unique_index(:phones, [:phone])

    create table(:tokens) do
      add :phone_id, references(:phones, on_delete: :delete_all), null: false
      add :token, :binary, null: false, size: 32
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :naive_datetime

      timestamps(updated_at: false)
    end

    create index(:tokens, [:phone_id])
    create unique_index(:tokens, [:context, :token])
  end
end
