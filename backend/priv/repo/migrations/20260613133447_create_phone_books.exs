defmodule VideoConference.Repo.Migrations.CreatePhoneBooks do
  use Ecto.Migration

  def change do
    create table(:phone_books) do
      add :phone_id, references(:phones, on_delete: :delete_all), null: false
      add :host_id, :integer
      add :phone, :integer
      add :name, :string

      timestamps()
    end

    create index(:phone_books, [:phone_id])
    create index(:phone_books, [:phone])
  end
end
