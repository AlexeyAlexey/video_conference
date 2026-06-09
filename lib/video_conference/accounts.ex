defmodule VideoConference.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias VideoConference.Repo

  alias VideoConference.Accounts.{Phone, Token, PhoneCall}

  ## Database getters

  @doc """
  Gets a phone by phone.

  ## Examples

      iex> all()
      [%Phone{}]

      iex> all()
      []

  """
  def all(except_phone_numbers: except_phone_numbers) when is_list(except_phone_numbers) do
    Repo.all(from p in Phone, where: p.phone not in ^except_phone_numbers, order_by: p.phone)
  end

  @doc """
  Gets a phone by phone.

  ## Examples

      iex> get_by_phone(123)
      %Phone{}

      iex> get_by_phone(1234)
      nil

  """
  def get_by_phone(phone) when is_binary(phone) do
    Repo.get_by(Phone, phone: phone)
  end

  @doc """
  Gets a phone by phone and password.

  ## Examples

      iex> get_by_phone_and_password(11111, "correct_password")
      %Phone{}

      iex> get_by_phone_and_password(111111, "invalid_password")
      nil

  """
  def get_by_phone_and_password(phone, password)
      when is_integer(phone) and is_binary(password) do
    phone = Repo.get_by(Phone, phone: phone)
    if Phone.valid_password?(phone, password), do: phone
  end

  def get_by_phone_and_password(phone, password)
      when is_binary(phone) and is_binary(password) do
    get_by_phone_and_password(String.to_integer(phone), password)
  end

  def get_by_phone_and_password(_phone, _password) do
    nil
  end

  @doc """
  Gets a single phone.

  Raises `Ecto.NoResultsError` if the Phone does not exist.

  ## Examples

      iex> get_phone!(123)
      %Phone{}

      iex> get_phone!(456)
      ** (Ecto.NoResultsError)

  """
  def get_phone!(id), do: Repo.get!(Phone, id)

  ## Phone registration

  @doc """
  Registers a phone.

  ## Examples

      iex> register_phone(%{field: value})
      {:ok, %Phone{}}

      iex> register_phone(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_phone(attrs) do
    %Phone{}
    |> Phone.register_changeset(attrs)
    |> Repo.insert()
  end

  def log_out(session_token: session_token) do
    delete_session_token(session_token)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the phone password.

  See `VideoConference.Accounts.Phone.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_phone_password(phone)
      %Ecto.Changeset{data: %Phone{}}

  """
  def change_phone_password(phone, attrs \\ %{}, opts \\ []) do
    Phone.password_changeset(phone, attrs, opts)
  end

  @doc """
  Updates the phone password.

  Returns a tuple with the updated phone, as well as a list of expired tokens.

  ## Examples

      iex> update_phone_password(phone, %{password: ...})
      {:ok, {%Phone{}, [...]}}

      iex> update_phone_password(phone, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """

  def update_phone_password(phone, attrs) do
    phone
    |> Phone.password_changeset(attrs)
    |> update_phone_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_session_token(%Phone{} = phone) do
    {token, phone_token} = Token.build_session_token(phone)
    Repo.insert!(phone_token)

    token
  end

  @doc """
  Gets the phone with the given signed token.

  If the token is valid `{phone, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_by_session_token(token) do
    {:ok, query} = Token.verify_session_token_query(token)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      {%Phone{} = phone, token_inserted_at} -> {:ok, {phone, token_inserted_at}}
    end
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(from(Token, where: [token: ^token, context: "session"]))
    :ok
  end

  def call_to(attrs) do
    %PhoneCall{}
    |> PhoneCall.call_changeset(attrs)
    |> Repo.insert()
  end

  ## Token helper

  defp update_phone_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, phone} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(Token, phone_id: phone.id)

        Repo.delete_all(from(t in Token, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {phone, tokens_to_expire}}
      end
    end)
  end
end
