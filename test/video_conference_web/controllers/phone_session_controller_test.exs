defmodule VideoConferenceWeb.PhoneSessionControllerTest do
  use VideoConferenceWeb.ConnCase

  import VideoConference.AccountsFixtures
  import VideoConference.CustomCase

  describe "POST /phones/log-in" do
    setup %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn}
    end

    test "success", %{conn: conn} do
      password = generate_password()

      phone_account =
        create_phone_account(12345, password)

      conn =
        post(conn, ~p"/phones/log-in", %{"phone" => phone_account.phone, "password" => password})

      assert %{"auth_token" => auth_token} =
               json_response(conn, 200)

      assert {:ok, %{"session_token" => session_token}} =
               verify_and_validate_account_auth_token(auth_token)

      verify_session_phone_token(phone_account.phone, session_token)
    end

    test "invalid password", %{conn: conn} do
      password = generate_password()

      phone_account =
        create_phone_account(12345, password)

      conn =
        post(conn, ~p"/phones/log-in", %{
          "phone" => phone_account.phone,
          "password" => "InvalidPassword"
        })

      assert %{"errors" => %{"detail" => "Invalid phone or password"}} =
               json_response(conn, 401)
    end

    test "invalid phone", %{conn: conn} do
      password = generate_password()

      create_phone_account(12345, password)

      conn =
        post(conn, ~p"/phones/log-in", %{
          "phone" => 87654,
          "password" => password
        })

      assert %{"errors" => %{"detail" => "Invalid phone or password"}} =
               json_response(conn, 401)
    end
  end

  describe "DELETE /phones/log-out" do
    setup %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")

      phone =
        create_phone_account(12345, generate_password())

      {:ok, conn: conn, phone: phone}
    end

    test "logs the phone out", %{conn: conn, phone: phone} do
      conn = conn |> log_in(phone) |> delete(~p"/phones/log-out")

      assert json_response(conn, 204) == nil
    end
  end
end
