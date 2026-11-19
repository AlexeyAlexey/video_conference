defmodule VideoConference.AdminPortal.Accounts do
  @moduledoc """
  The AdminPortal Accounts context.
  """

  import Ecto.Query, warn: false
  alias VideoConference.Repo

  alias VideoConference.AdminPortal.Accounts.{Admin, Token}

  ## Database getters

  @doc """
  Gets an admin by email.

  ## Examples

      iex> get_admin_by_email("admin@admin.com")
      %Admin{}

      iex> get_admin_by_email("unknown@example.com")
      nil

  """
  def get_admin_by_email(email) when is_binary(email) do
    Repo.get_by(Admin, email: email)
  end

  @doc """
  Gets an admin by email and password.

  ## Examples

      iex> get_admin_by_email_and_password("admin@admin.com", "correct_password")
      %Admin{}

      iex> get_admin_by_email_and_password("admin@admin.com", "invalid_password")
      nil

  """
  def get_admin_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    admin = Repo.get_by(Admin, email: email)
    if Admin.valid_password?(admin, password), do: admin
  end

  ## Admin registration

  @doc """
  Registers an admin.

  ## Examples

      iex> register_admin(%{field: value})
      {:ok, %Admin{}}

      iex> register_admin(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_admin(attrs) do
    %Admin{}
    |> Admin.registration_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the admin password.

  See `VideoConference.AdminPortal.Accounts.Admin.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_admin_password(admin)
      %Ecto.Changeset{data: %Admin{}}

  """
  def change_admin_password(admin, attrs \\ %{}, opts \\ []) do
    Admin.password_changeset(admin, attrs, opts)
  end

  @doc """
  Updates the admin password.

  Returns a tuple with the updated admin, as well as a list of expired tokens.

  ## Examples

      iex> update_admin_password(admin, %{password: ...})
      {:ok, {%Admin{}, [...]}}

      iex> update_admin_password(admin, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_admin_password(admin, attrs) do
    admin
    |> Admin.password_changeset(attrs, validate_current: true)
    |> update_admin_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_session_token(%Admin{} = admin) do
    {token, admin_token} = Token.build_session_token(admin)
    Repo.insert!(admin_token)

    token
  end

  @doc """
  Gets the admin with the given signed token.

  If the token is valid `{admin, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_admin_by_session_token(token) do
    {:ok, query} = Token.verify_session_token_query(token)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      {%Admin{} = admin, token_inserted_at} -> {:ok, {admin, token_inserted_at}}
    end
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(from(Token, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_admin_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, admin} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(Token, admin_id: admin.id)

        Repo.delete_all(from(t in Token, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {admin, tokens_to_expire}}
      end
    end)
  end
end
