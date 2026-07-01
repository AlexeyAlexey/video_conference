defmodule VideoConference.TelephoneSwitchboard.SharedLinks.SharedLink do
  use Ecto.Schema
  import Ecto.Changeset

  alias VideoConference.Accounts.Phone

  schema "shared_links" do
    field :name, :string
    field :link_id, :string
    field :password_required, :boolean
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true

    timestamps()

    belongs_to :account, Phone, foreign_key: :phone_id
  end

  def changeset(%__MODULE__{} = shared_link, attrs, opts \\ []) do
    shared_link
    |> cast(attrs, [:phone_id, :name, :link_id, :password_required, :password])
    |> validate_required([:phone_id])
    |> validate_password(opts)
  end

  def generate_changeset(%__MODULE__{} = shared_link, attrs, opts \\ []) do
    shared_link
    |> cast(attrs, [:phone_id, :name, :link_id, :password_required, :password])
    |> validate_required([:phone_id, :name, :link_id, :password_required])
    |> validate_password(opts)
  end

  def enable_password_changeset(
        %__MODULE__{} = shared_link,
        attrs,
        opts \\ []
      ) do
    opts = Keyword.put(opts, :password_required, true)

    shared_link
    |> cast(attrs, [:password_required, :password])
    |> validate_required([:password_required, :password])
    |> validate_password(opts)
  end

  def disable_password_changeset(%__MODULE__{} = shared_link, attrs, _opts \\ []) do
    shared_link
    |> cast(attrs, [:password_required, :hashed_password])
  end

  defp validate_password(changset, opts) do
    if Keyword.get(opts, :password_required, false) do
      changset
      |> validate_required([:password])
      |> validate_length(:password, min: 3, max: 72)
      |> maybe_hash_password(opts)
    else
      changset
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  def password_required(%__MODULE__{password_required: true}), do: true
  def password_required(%__MODULE__{password_required: false}), do: false
end
