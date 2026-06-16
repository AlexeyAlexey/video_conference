defmodule VideoConferenceWeb.PhoneBookJSON do
  alias VideoConference.PhoneBooks.PhoneBook

  def record(%{phone_book: %PhoneBook{} = phone_book}) do
    phone_record(phone_book)
  end

  def list(%{phone_books: phone_books}) do
    Enum.map(phone_books, &phone_record/1)
  end

  defp phone_record(%PhoneBook{id: id, host_id: host_id, phone: phone, name: name}) do
    %{"id" => id, "host_id" => host_id, "phone" => phone, "name" => name}
  end
end
