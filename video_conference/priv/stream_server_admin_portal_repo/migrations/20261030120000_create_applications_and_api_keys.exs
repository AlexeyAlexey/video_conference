defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.CreateApplicationsAndApiKeys do
  use Ecto.Migration

  def change do
    create table(:applications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :enabled, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:applications, [:name])

    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :application_id,
          references(:applications, type: :binary_id, on_delete: :delete_all),
          null: false

      add :name, :string, null: false
      add :hashed_api_key, :string, null: false
      add :description, :text
      add :enabled, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:api_keys, [:application_id, :name])
    create unique_index(:api_keys, [:application_id, :hashed_api_key])
  end
end
