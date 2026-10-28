defmodule VideoConference.AdminPortal.StreamServers.PublicStreamServerKey do
  @moduledoc """
  A public/private signing key pair registered for a stream server.

  `private_key` persists ciphertext produced by `KeyEncryption`. The
  virtual `private_key_pem` field receives plaintext form input: a
  non-blank value is encrypted into `private_key`, while a blank value
  on update keeps the stored key. It is required when creating a record
  through the regular changeset; the generate flow uses
  `generate_changeset/2` instead, which has no key-material inputs.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias VideoConference.AdminPortal.StreamServers.{KeyEncryption, StreamServer}

  schema "public_stream_server_keys" do
    field :name, :string
    field :public_key_id, :string
    field :public_key, :string
    field :private_key, :string
    field :disabled, :boolean, default: false
    field :description, :string

    field :private_key_pem, :string, virtual: true

    belongs_to :stream_server, StreamServer

    timestamps()
  end

  @doc """
  A public stream server key changeset.

  Requires `name`, `public_key`, and `stream_server_id`. `private_key_pem`
  is required when the record has no stored `private_key` yet; on update a
  blank `private_key_pem` keeps the stored key and a non-blank value
  replaces it (re-encrypted). `name` must be unique per stream server.
  """
  def changeset(%__MODULE__{} = key, attrs) do
    key
    |> cast(attrs, [
      :name,
      :public_key_id,
      :public_key,
      :private_key_pem,
      :stream_server_id,
      :disabled,
      :description
    ])
    |> validate_required([:name, :public_key, :stream_server_id])
    |> validate_private_key_pem()
    |> put_private_key()
    |> unsafe_validate_unique([:name, :stream_server_id], VideoConference.Repo)
    |> unique_constraint([:stream_server_id, :name])
    |> assoc_constraint(:stream_server)
  end

  @doc """
  A changeset for the generate flow. Validates the admin-provided fields
  (`name`, `stream_server_id`, `description`); key material is added by the
  context after generation.
  """
  def generate_changeset(%__MODULE__{} = key, attrs) do
    key
    |> cast(attrs, [:name, :stream_server_id, :description])
    |> validate_required([:name, :stream_server_id])
    |> unsafe_validate_unique([:name, :stream_server_id], VideoConference.Repo)
    |> unique_constraint([:stream_server_id, :name])
    |> assoc_constraint(:stream_server)
  end

  defp validate_private_key_pem(changeset) do
    if is_nil(changeset.data.private_key) do
      validate_required(changeset, [:private_key_pem])
    else
      changeset
    end
  end

  defp put_private_key(changeset) do
    case fetch_change(changeset, :private_key_pem) do
      {:ok, pem} when is_binary(pem) and pem != "" ->
        put_change(changeset, :private_key, KeyEncryption.encrypt(pem))

      _ ->
        changeset
    end
  end
end
