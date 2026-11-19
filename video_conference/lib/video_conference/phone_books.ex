defmodule VideoConference.PhoneBooks do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias VideoConference.Repo

  alias VideoConference.PhoneBooks.PhoneBook
  alias VideoConference.Accounts.Phone
  alias VideoConference.Accounts.Scope

  def list(%Scope{phone: %Phone{id: phone_id}}) do
    Repo.all(from b in PhoneBook, where: b.phone_id == ^phone_id, order_by: b.phone)
  end

  def add(%Scope{phone: %Phone{id: phone_id}}, attrs) do
    attrs = attrs |> Map.put("phone_id", phone_id)

    %PhoneBook{}
    |> PhoneBook.changeset(attrs)
    |> Repo.insert()
  end

  def remove(%Scope{phone: %Phone{id: phone_id}}, id: id) do
    with {:ok, phone_book} <- find_for(%Scope{phone: %Phone{id: phone_id}}, id: id),
         {:ok, phone_book} <- Repo.delete(phone_book) do
      {:ok, phone_book}
    else
      {:error, :not_found} ->
        {:error, :not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  def find_for(%Scope{phone: %Phone{id: phone_id}}, id: id) do
    from(b in PhoneBook, where: b.id == ^id and b.phone_id == ^phone_id)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      phone_book ->
        {:ok, phone_book}
    end
  end
end
