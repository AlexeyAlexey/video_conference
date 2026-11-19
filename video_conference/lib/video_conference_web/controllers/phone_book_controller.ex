defmodule VideoConferenceWeb.PhoneBookController do
  use VideoConferenceWeb, :controller

  action_fallback VideoConferenceWeb.FallbackController

  alias VideoConference.PhoneBooks.PhoneBook

  def list(conn, _params) do
    phone_books = VideoConference.PhoneBooks.list(conn.assigns.current_scope)

    render(conn, :list, %{phone_books: phone_books})
  end

  def add_phone(conn, params) do
    VideoConference.PhoneBooks.add(conn.assigns.current_scope, params)
    |> case do
      {:ok, %PhoneBook{} = phone_book} ->
        render(conn, :record, %{phone_book: phone_book})

      error ->
        error
    end
  end

  def remove_phone(conn, %{"id" => id}) do
    VideoConference.PhoneBooks.remove(conn.assigns.current_scope, id: id)

    conn
    |> put_status(204)
    |> json(nil)
  end
end
