defmodule VideoConference.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `VideoConference.Accounts` context.
  """

  # import Ecto.Query

  alias VideoConference.Accounts
  alias VideoConference.Accounts.Scope
  alias VideoConference.Accounts.Phone

  def unique_phone, do: Enum.random(0..1_000_000)
  def valid_phone_password, do: "hello world!"

  def create_phone_account(phone, password) when is_integer(phone) and is_binary(password) do
    {:ok, %Phone{} = phone_account} =
      Accounts.register_phone(%{
        "phone" => phone,
        "password" => password,
        "password_confirmation" => password
      })

    phone_account
  end

  def create_phone_account(phone) when is_integer(phone) do
    {:ok, %Phone{} = phone_account} =
      Accounts.register_phone(%{
        "phone" => phone,
        "password" => valid_phone_password(),
        "password_confirmation" => valid_phone_password()
      })

    phone_account
  end

  def phone_scope_fixture(phone) do
    Scope.for(phone)
  end

  def set_password(phone) do
    {:ok, {phone, _expired_tokens}} =
      Accounts.update_phone_password(phone, %{password: valid_phone_password()})

    phone
  end
end
