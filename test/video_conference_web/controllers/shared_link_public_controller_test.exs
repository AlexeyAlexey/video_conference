defmodule VideoConferenceWeb.SharedLinkPublicControllerTest do
  use VideoConferenceWeb.ConnCase

  import VideoConference.AccountsFixtures
  import VideoConference.CustomCase
  import VideoConference.TelephoneSwitchboard.SharedLinksFixtures
  alias VideoConference.TelephoneSwitchboard.AuthTokenTestHelper

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
          link_id: generate_shared_link_link_id(),
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
          link_id: generate_shared_link_link_id(),
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

  describe "POST /conference/public/shared_link/conference_credentials/:link_id" do
    test "returns conference credentials when password is provided and correct", %{
      conn: conn,
      phone: phone
    } do
      shared_link =
        create_shared_link(%{
          phone_id: phone.id,
          name: "Test Link",
          link_id: generate_shared_link_link_id(),
          password_required: true,
          password: "secret123"
        })

      conn =
        post(
          conn,
          ~p"/conference/public/shared_link/conference_credentials/#{shared_link.link_id}",
          %{
            "password" => "secret123"
          }
        )

      response = json_response(conn, 200)

      assert response["switchboard_video_uri"]
      assert response["switchboard_audio_uri"]

      assert response["switchboard_video_server_cert_hash"]
      assert response["switchboard_audio_server_cert_hash"]
    end

    test "returns conference credentials when password is not required", %{
      conn: conn,
      phone: phone
    } do
      shared_link =
        create_shared_link(%{
          phone_id: phone.id,
          name: "Test Link",
          link_id: generate_shared_link_link_id(),
          password_required: false
        })

      conn =
        post(
          conn,
          ~p"/conference/public/shared_link/conference_credentials/#{shared_link.link_id}",
          %{}
        )

      response = json_response(conn, 200)

      assert response["switchboard_video_uri"]
      assert response["switchboard_audio_uri"]

      assert response["switchboard_video_server_cert_hash"]
      assert response["switchboard_audio_server_cert_hash"]
    end

    test "switchboard_video_uri and switchboard_audio_uri auth tokens params", %{
      conn: conn,
      phone: phone
    } do
      link_id = generate_shared_link_link_id()

      shared_link =
        create_shared_link(%{
          phone_id: phone.id,
          name: "Test Link",
          link_id: link_id,
          password_required: false
        })

      conn =
        post(
          conn,
          ~p"/conference/public/shared_link/conference_credentials/#{shared_link.link_id}",
          %{}
        )

      response = json_response(conn, 200)

      assert {:ok,
              %{
                "conference_id" => ^link_id,
                "type" => "conference",
                "stream_type" => "video"
              }} =
               AuthTokenTestHelper.parse_and_decode_token_from_uri(
                 response["switchboard_video_uri"]
               )

      assert {:ok,
              %{
                "conference_id" => ^link_id,
                "type" => "conference",
                "stream_type" => "audio"
              }} =
               AuthTokenTestHelper.parse_and_decode_token_from_uri(
                 response["switchboard_audio_uri"]
               )
    end

    test "returns error when password is required but not provided", %{conn: conn, phone: phone} do
      shared_link =
        create_shared_link(%{
          phone_id: phone.id,
          name: "Test Link",
          link_id: generate_shared_link_link_id(),
          password_required: true,
          password: "secret123"
        })

      conn =
        post(
          conn,
          ~p"/conference/public/shared_link/conference_credentials/#{shared_link.link_id}",
          %{}
        )

      assert json_response(conn, 422) == %{"errors" => %{"detail" => "requires password"}}
    end

    test "returns error when password is incorrect", %{conn: conn, phone: phone} do
      shared_link =
        create_shared_link(%{
          phone_id: phone.id,
          name: "Test Link",
          link_id: generate_shared_link_link_id(),
          password_required: true,
          password: "secret123"
        })

      conn =
        post(
          conn,
          ~p"/conference/public/shared_link/conference_credentials/#{shared_link.link_id}",
          %{
            "password" => "wrongpassword"
          }
        )

      assert json_response(conn, 422) == %{"errors" => %{"detail" => "invalid password"}}
    end

    test "returns 404 when shared link does not exist", %{conn: conn} do
      fake_shared_link = generate_shared_link_link_id()

      conn =
        post(
          conn,
          ~p"/conference/public/shared_link/conference_credentials/#{fake_shared_link}",
          %{}
        )

      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end
  end
end
