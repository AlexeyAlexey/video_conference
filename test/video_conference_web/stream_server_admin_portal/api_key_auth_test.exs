defmodule VideoConferenceWeb.StreamServerAdminPortal.ApiKeyAuthTest do
  use VideoConferenceWeb.ConnCase, async: false

  import VideoConference.StreamServerAdminPortalFixtures

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.StreamServers
  alias VideoConferenceWeb.StreamServerAdminPortal.ApiKeyAuth

  describe "call/2" do
    test "assigns {:stream_server, key} for a valid ssak_ secret", %{conn: conn} do
      {key, secret} = stream_server_api_key_with_secret_fixture(stream_server_fixture())

      conn =
        conn
        |> put_req_header("x-api-key", secret)
        |> ApiKeyAuth.call([])

      refute conn.halted
      assert {:stream_server, assigned} = conn.assigns.api_credential
      assert assigned.id == key.id
    end

    test "assigns {:application, key} for a valid aak_ secret", %{conn: conn} do
      {key, secret} = api_key_with_secret_fixture(application_fixture())

      conn =
        conn
        |> put_req_header("x-api-key", secret)
        |> ApiKeyAuth.call([])

      refute conn.halted
      assert {:application, assigned} = conn.assigns.api_credential
      assert assigned.id == key.id
    end

    test "rejects a request without an X-API-Key header", %{conn: conn} do
      conn = ApiKeyAuth.call(conn, [])

      assert conn.halted
      assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
    end

    test "rejects a malformed secret" do
      for secret <- ["", "not-a-key", "ssak_not-a-uuid_random", "ssak_#{Ecto.UUID.generate()}"] do
        conn =
          Phoenix.ConnTest.build_conn()
          |> put_req_header("x-api-key", secret)
          |> ApiKeyAuth.call([])

        assert conn.halted
        assert conn.status == 401
        assert conn.assigns[:api_credential] == nil
      end
    end

    test "rejects a secret with an unrecognized env_prefix", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-api-key", "xyz_#{Ecto.UUID.generate()}_random")
        |> ApiKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects a secret whose prefix matches no stored credential", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-api-key", "ssak_#{Ecto.UUID.generate()}_random")
        |> ApiKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects a wrong secret for a known prefix", %{conn: conn} do
      {key, _secret} = stream_server_api_key_with_secret_fixture(stream_server_fixture())

      conn =
        conn
        |> put_req_header("x-api-key", key.prefix <> "_wrongsecret")
        |> ApiKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects a valid secret for a disabled credential", %{conn: conn} do
      {key, secret} = stream_server_api_key_with_secret_fixture(stream_server_fixture())
      {:ok, _key} = StreamServers.disable_stream_server_api_key(key.id)

      conn =
        conn
        |> put_req_header("x-api-key", secret)
        |> ApiKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects a valid secret for a disabled application credential", %{conn: conn} do
      {key, secret} = api_key_with_secret_fixture(application_fixture())
      {:ok, _key} = Applications.disable_api_key(key.id)

      conn =
        conn
        |> put_req_header("x-api-key", secret)
        |> ApiKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "rejects a valid secret for an enabled key on a disabled application", %{conn: conn} do
      application = application_fixture()
      {_key, secret} = api_key_with_secret_fixture(application)
      {:ok, _application} = Applications.disable_application(application.id)

      conn =
        conn
        |> put_req_header("x-api-key", secret)
        |> ApiKeyAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert conn.assigns[:api_credential] == nil
    end
  end
end
