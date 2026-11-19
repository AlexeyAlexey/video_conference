defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.CreateEventListeners do
  use Ecto.Migration

  def change do
    create table(:event_listeners, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false
      add :description, :string, null: false, default: ""
      add :last_seen_seq, :bigint, null: false, default: 0
      add :status, :string, null: false, default: "ok"
      add :last_error, :string
    end

    create unique_index(:event_listeners, [:name])
  end
end
