defmodule VideoConference.AdminPortal.Accounts.Admin do
  use Ecto.Schema
  import Ecto.Changeset

  schema "admins" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :current_password, :string, virtual: true, redact: true
    field :authenticated_at, :utc_datetime, virtual: true

    timestamps()
  end

  @doc """
  An admin changeset for registration.

  It is important to validate the length of the email and password, as
  long passwords may be very expensive to hash for certain algorithms.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def registration_changeset(admin, attrs, opts \\ []) do
    admin
    |> cast(attrs, [:email, :password])
    |> validate_email(opts)
    |> validate_confirmation(:password, required: true, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, VideoConference.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  An admin changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_current` - Validates that the given `current_password`
      matches the admin's stored password. Defaults to `false`.
  """
  def password_changeset(admin, attrs, opts \\ []) do
    admin
    |> cast(attrs, [:password, :current_password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
    |> maybe_validate_current_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 3, max: 72)
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
      |> delete_change(:password_confirmation)
    else
      changeset
    end
  end

  defp maybe_validate_current_password(changeset, opts) do
    if Keyword.get(opts, :validate_current, false) do
      changeset
      |> validate_required([:current_password])
      |> validate_change(:current_password, fn :current_password, current_password ->
        if valid_password?(changeset.data, current_password) do
          []
        else
          [current_password: "is not valid"]
        end
      end)
    else
      changeset
    end
  end

  @doc """
  Verifies the password.

  If there is no admin or the admin doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
