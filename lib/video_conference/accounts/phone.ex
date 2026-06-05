defmodule VideoConference.Accounts.Phone do
  use Ecto.Schema
  import Ecto.Changeset

  schema "phones" do
    field :phone, :integer
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime
    field :authenticated_at, :naive_datetime, virtual: true

    timestamps()
  end

  @doc """
  A phone changeset for registering or changing the phone.

  It requires the phone to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the phone, useful when displaying live validations.
      Defaults to `true`.
  """
  def phone_changeset(phone, attrs, opts \\ []) do
    phone
    |> cast(attrs, [:phone])
    |> validate_phone(opts)
  end

  def register_changeset(%__MODULE__{} = phone, attrs, opts \\ []) do
    phone
    |> cast(attrs, [:phone, :password])
    |> validate_phone(opts)
    |> validate_confirmation(:password, required: true, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_phone(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:phone])
      |> validate_number(:phone, less_than_or_equal_to: 1_000_000)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:phone, VideoConference.Repo)
      |> unique_constraint(:phone)
      |> validate_phone_changed()
    else
      changeset
    end
  end

  defp validate_phone_changed(changeset) do
    if get_field(changeset, :phone) && get_change(changeset, :phone) == nil do
      add_error(changeset, :phone, "did not change")
    else
      changeset
    end
  end

  @doc """
  A phone changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(phone, attrs, opts \\ []) do
    phone
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 3, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
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

  @doc """
  Verifies the password.

  If there is no phone or the phone doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%VideoConference.Accounts.Phone{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
