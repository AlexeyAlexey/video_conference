defmodule VideoConference.Repo.Migrations.CreatePhoneCalls do
  use Ecto.Migration

  def change do
    create table(:phone_calls) do
      # utc datetime in milliseconds
      add :called_at, :integer, null: false
    end

    create index(:phone_calls, [:called_at])

    create table(:phone_call_participants) do
      add :phone_call_id, :integer, null: false
      add :phone_call_called_at, :integer, null: false
      add :host_id, :integer
      add :phone, :integer
      # (income/outcome)
      add :direction, :string

      timestamps()
    end

    create index(:phone_call_participants, [:phone_call_id, :phone_call_called_at])
    create index(:phone_call_participants, [:phone, :direction])
  end
end
