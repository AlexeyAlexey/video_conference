defmodule VideoConference.StreamServerAdminPortal.Applications.ApiKey do
  @moduledoc """
  An API key credential belonging to an application.

  `hashed_api_key` persists the bcrypt hash of the generated secret. The
  virtual `plaintext_key` carries the secret back to the caller at creation
  time only — it is never stored, and the key's secret is immutable after
  creation (the changeset never casts it).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias VideoConference.StreamServerAdminPortal.Applications.Application
  alias VideoConference.StreamServerAdminPortal.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "api_keys" do
    field :name, :string
    field :hashed_api_key, :string, redact: true
    field :description, :string
    field :enabled, :boolean, default: true

    field :plaintext_key, :string, virtual: true, redact: true

    belongs_to :application, Application

    timestamps()
  end

  @doc """
  An API key changeset.

  Requires `name` and `application_id`; the key name must be unique within
  its application (the same name is allowed on different applications).
  """
  def changeset(%__MODULE__{} = api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :description, :enabled, :application_id])
    |> validate_required([:name, :application_id])
    |> unsafe_validate_unique([:name, :application_id], Repo)
    |> unique_constraint([:application_id, :name])
    |> unique_constraint([:application_id, :hashed_api_key])
    |> assoc_constraint(:application)
  end
end
