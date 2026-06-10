defmodule VideoConference.Repo.Migrations.CreatePhoneCalls do
  use Ecto.Migration

  def change do
    create table(:phone_calls) do
      add :from_host, :string
      add :from, :integer
      add :to_host, :string
      add :to, :integer

      add :called_at, :integer, null: false
      add :responded_at, :integer
      add :ended_at, :integer

      timestamps()
    end

    create index(:phone_calls, [:from])
    create index(:phone_calls, [:to])
    create index(:phone_calls, [:called_at])
  end
end
