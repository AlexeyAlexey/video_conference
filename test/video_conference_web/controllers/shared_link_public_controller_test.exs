defmodule VideoConferenceWeb.SharedLinkPublicControllerTest do
  use VideoConferenceWeb.ConnCase

  import VideoConference.AccountsFixtures
  import VideoConference.CustomCase
  import VideoConference.SharedLinksFixtures

  setup %{conn: conn} do
    phone =
      create_phone_account(unique_phone(), generate_password())

    conn =
      conn
      |> put_req_header("accept", "application/json")

    {:ok, conn: conn, phone: phone}
  end

  describe "GET /conference/public/shared_link/info/:link_id" do
    test "returns shared link info when authenticated and link exists", %{
      conn: conn,
      phone: phone
    } do
      conn = conn |> log_in(phone)

      shared_link =
        create_shared_link(%{
          phone_id: phone.id,
          name: "Test Link",
          link_id: "abc123",
          password_required: false
        })

      conn = get(conn, ~p"/conference/public/shared_link/info/#{shared_link.link_id}")

      response = json_response(conn, 200)
      assert response["link_id"] == shared_link.link_id
      assert response["password_required"] == false
      assert response["link"]
    end

    test "returns shared link info when not authenticated and link exists", %{
      conn: conn,
      phone: phone
    } do
      shared_link =
        create_shared_link(%{
          phone_id: phone.id,
          name: "Test Link",
          link_id: "abc123",
          password_required: false
        })

      conn = get(conn, ~p"/conference/public/shared_link/info/#{shared_link.link_id}")

      response = json_response(conn, 200)
      assert response["link_id"] == shared_link.link_id
      assert response["password_required"] == false
      assert response["link"]
    end

    test "returns 404 when shared link does not exist", %{conn: conn} do
      fake_shared_link = "abc123"

      conn = get(conn, ~p"/conference/public/shared_link/info/#{fake_shared_link}")

      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end
  end
end
