defmodule VideoConference.PhoneBookFixtures do
  # import Ecto.Query
  alias VideoConference.Repo

  alias VideoConference.Accounts.Phone
  alias VideoConference.PhoneBooks.PhoneBook

  def add_phone_to_phone_book_for(%Phone{id: phone_id}, attrs) when is_map(attrs) do
    attrs = Map.put(attrs, :phone_id, phone_id)

    {:ok, phone_book} =
      %PhoneBook{}
      |> PhoneBook.changeset(attrs)
      |> Repo.insert()

    phone_book
  end

  def fake_phone_book_id, do: Enum.random(1..1_000_000_000)
end
