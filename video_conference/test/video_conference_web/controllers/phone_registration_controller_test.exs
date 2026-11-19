defmodule VideoConferenceWeb.PhoneRegistrationControllerTest do
  use VideoConferenceWeb.ConnCase

  import VideoConference.AccountsFixtures
  import VideoConference.CustomCase

  setup %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")

    {:ok, conn: conn}
  end

  describe "POST /phones/register" do
    test "password is required", %{conn: conn} do
      phone = unique_phone()

      conn =
        post(conn, ~p"/phones/register", %{
          "phone" => phone,
          "invitation_token" => invitation_token()
        })

      assert(
        %{"errors" => %{"password" => ["can't be blank"]}} =
          json_response(conn, 422)
      )
    end

    test "password confirmation is required", %{conn: conn} do
      phone = unique_phone()

      conn =
        post(conn, ~p"/phones/register", %{
          "phone" => phone,
          "password" => "qwed4fghhfffffh",
          "invitation_token" => invitation_token()
        })

      assert(
        %{"errors" => %{"password_confirmation" => ["does not match password"]}} =
          json_response(conn, 422)
      )
    end

    test "creates account but does not log in", %{conn: conn} do
      phone = unique_phone()
      password = "qwed4fghhfffffh"

      conn =
        post(conn, ~p"/phones/register", %{
          "phone" => phone,
          "password" => password,
          "password_confirmation" => password,
          "invitation_token" => invitation_token()
        })

      assert(
        %{
          "auth_token" => auth_token
        } = json_response(conn, 200)
      )

      {:ok, %{"session_token" => session_token}} =
        verify_and_validate_account_auth_token(auth_token)

      verify_session_phone_token(phone, session_token)
    end
  end
end
