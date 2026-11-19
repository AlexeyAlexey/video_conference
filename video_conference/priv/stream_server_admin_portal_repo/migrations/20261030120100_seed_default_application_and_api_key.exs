defmodule VideoConference.StreamServerAdminPortal.Repo.Migrations.SeedDefaultApplicationAndApiKey do
  use Ecto.Migration

  import Ecto.Query

  @application_name "Default App"

  @application_description "Default application seeded at deploy time. It must be replaced for production use."

  @api_key_name "Default API Key"

  @api_key_description "Default API key seeded at deploy time. It must be replaced for production use."

  def up do
    now = DateTime.utc_now(:second)

    repo().insert_all(
      "applications",
      [
        [
          id: default_application_id(),
          name: @application_name,
          description: @application_description,
          enabled: 1,
          inserted_at: now,
          updated_at: now
        ]
      ],
      on_conflict: :nothing
    )

    application_id =
      repo().one(
        from(a in "applications", where: a.name == ^@application_name, select: a.id)
      )

    repo().insert_all(
      "api_keys",
      [
        [
          id: Ecto.UUID.generate(),
          application_id: application_id,
          name: @api_key_name,
          hashed_api_key: Bcrypt.hash_pwd_salt(default_api_key_secret()),
          description: @api_key_description,
          enabled: 1,
          inserted_at: now,
          updated_at: now
        ]
      ],
      on_conflict: :nothing
    )
  end

  def down do
    repo().delete_all(from(k in "api_keys", where: k.name == ^@api_key_name))
    repo().delete_all(from(a in "applications", where: a.name == ^@application_name))
  end

  defp default_application_id do
    with value when is_binary(value) <- System.get_env("DEFAULT_STREAM_SERVER_APP_ID"),
         {:ok, uuid} <- Ecto.UUID.cast(value) do
      uuid
    else
      _ -> Ecto.UUID.generate()
    end
  end

  defp default_api_key_secret do
    case System.get_env("DEFAULT_STREAM_SERVER_API_KEY") do
      secret when is_binary(secret) and secret != "" -> secret
      _ -> "ssak_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    end
  end
end
