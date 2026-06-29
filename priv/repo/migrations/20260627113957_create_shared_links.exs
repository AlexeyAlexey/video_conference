defmodule VideoConference.Repo.Migrations.CreateSharedLinks do
  use Ecto.Migration

  def change do
    create table(:shared_links) do
      add :phone_id, references(:phones, on_delete: :delete_all), null: false
      add :name, :string
      add :link_id, :string
      add :password_required, :boolean
      add :hashed_password, :string

      timestamps()
    end

    create unique_index(:shared_links, [:phone_id, :link_id])
  end
end
