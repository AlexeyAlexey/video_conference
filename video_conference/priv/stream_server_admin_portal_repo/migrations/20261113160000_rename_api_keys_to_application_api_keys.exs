defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.RenameApiKeysToApplicationApiKeys do
  use Ecto.Migration

  import Ecto.Query

  alias VideoConference.StreamServerAdminPortal.ApiKeySecret

  def up do
    drop unique_index(:api_keys, [:application_id, :name])
    drop unique_index(:api_keys, [:application_id, :hashed_api_key])

    rename table(:api_keys), to: table(:application_api_keys)

    alter table(:application_api_keys) do
      add :prefix, :string, null: false, default: ""
      add :lock_version, :integer, null: false, default: 1
    end

    flush()

    for id <- repo().all(from(k in "application_api_keys", select: k.id)) do
      repo().update_all(
        from(k in "application_api_keys", where: k.id == ^id),
        set: [prefix: ApiKeySecret.prefix("aak", Ecto.UUID.generate())]
      )
    end

    create unique_index(:application_api_keys, [:prefix])
    create unique_index(:application_api_keys, [:application_id, :hashed_api_key])
  end

  def down do
    drop unique_index(:application_api_keys, [:prefix])
    drop unique_index(:application_api_keys, [:application_id, :hashed_api_key])

    alter table(:application_api_keys) do
      remove :prefix
      remove :lock_version
    end

    rename table(:application_api_keys), to: table(:api_keys)

    create unique_index(:api_keys, [:application_id, :name])
    create unique_index(:api_keys, [:application_id, :hashed_api_key])
  end
end
