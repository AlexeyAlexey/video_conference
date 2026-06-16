defmodule VideoConferenceWeb.PhoneBookControllerTest do
  use VideoConferenceWeb.ConnCase

  alias VideoConference.Repo

  import VideoConference.AccountsFixtures
  import VideoConference.PhoneBookFixtures
  import VideoConference.CustomCase

  alias VideoConference.PhoneBooks.PhoneBook

  describe "authentication" do
    setup %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn}
    end

    test "requires to be log in", %{conn: conn} do
      conn = conn |> post(~p"/phone_book/add_phone", %{"phone" => 123, "name" => "name"})

      assert json_response(conn, 401)
    end
  end

  describe "add phone" do
    setup %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")

      phone =
        create_phone_account(12345, generate_password())

      {:ok, conn: conn, phone: phone}
    end

    test "successfully add phone", %{conn: conn, phone: phone} do
      params = %{"phone" => 123, "name" => "New contact"}

      conn =
        conn
        |> log_in(phone)
        |> post(~p"/phone_book/add_phone", params)

      assert %{"id" => id, "host_id" => nil, "phone" => 123, "name" => "New contact"} =
               json_response(conn, 200)

      assert Repo.exists?(PhoneBook, id: id)
    end
  end

  describe "list" do
    setup %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")

      phone =
        create_phone_account(12345, generate_password())

      {:ok, conn: conn, phone: phone}
    end

    test "get list of phones", %{conn: conn, phone: phone} do
      add_phone_to_phone_book_for(phone, %{host_id: 1234, phone: 123, name: "New contact"})

      conn =
        conn
        |> log_in(phone)
        |> get(~p"/phone_book/list", %{})

      assert [%{"id" => _id, "host_id" => 1234, "phone" => 123, "name" => "New contact"}] =
               json_response(conn, 200)
    end
  end

  describe "remove phone from phone book" do
    setup %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")

      phone =
        create_phone_account(12345, generate_password())

      {:ok, conn: conn, phone: phone}
    end

    test "remove existing phone", %{conn: conn, phone: phone} do
      record =
        add_phone_to_phone_book_for(phone, %{host_id: 1234, phone: 123, name: "New contact"})

      assert Repo.exists?(PhoneBook, id: record.id)

      conn =
        conn
        |> log_in(phone)
        |> delete(~p"/phone_book/remove_phone", %{id: record.id})

      assert json_response(conn, 204) == nil

      refute Repo.exists?(PhoneBook, id: record.id)
    end

    test "remove fake phone", %{conn: conn, phone: phone} do
      record_id = fake_phone_book_id()

      refute Repo.exists?(PhoneBook, id: record_id)

      conn =
        conn
        |> log_in(phone)
        |> delete(~p"/phone_book/remove_phone", %{id: record_id})

      assert json_response(conn, 204) == nil

      refute Repo.exists?(PhoneBook, id: record_id)
    end
  end
end
