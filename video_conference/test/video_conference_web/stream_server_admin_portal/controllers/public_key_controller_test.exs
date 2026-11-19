defmodule VideoConferenceWeb.StreamServerAdminPortal.PublicKeyControllerTest do
  use VideoConferenceWeb.ConnCase, async: false

  import VideoConference.StreamServerAdminPortalFixtures

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.StreamServers

  @path "/stream-server-admin/api/stream-server/public-key"

  defp request(conn, secret, params) do
    conn
    |> put_req_header("x-api-key", secret)
    |> get(@path, params)
  end

  defp assigned_server_with_key do
    application = application_fixture()
    stream_server = stream_server_fixture()
    {:ok, _} = StreamServers.assign_application(stream_server.id, application.id)
    {api_key, secret} = stream_server_api_key_with_secret_fixture(stream_server)
    public_key = stream_server_public_key_fixture(application)

    %{
      application: application,
      stream_server: stream_server,
      api_key: api_key,
      secret: secret,
      public_key: public_key
    }
  end

  describe "GET /stream-server-admin/api/stream-server/public-key" do
    test "returns the public key material for an assigned application", %{conn: conn} do
      %{application: application, secret: secret, public_key: public_key} =
        assigned_server_with_key()

      conn =
        request(conn, secret, %{
          "application_id" => application.id,
          "public_key_id" => public_key.id
        })

      assert json_response(conn, 200) == %{
               "application_id" => application.id,
               "public_key_id" => public_key.id,
               "key" => public_key.key
             }
    end

    test "rejects a request without an X-API-Key header", %{conn: conn} do
      conn = get(conn, @path)

      assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
    end

    test "rejects a wrong secret", %{conn: conn} do
      %{application: application, public_key: public_key} = assigned_server_with_key()

      conn =
        request(conn, "ssak_#{Ecto.UUID.generate()}_bogus", %{
          "application_id" => application.id,
          "public_key_id" => public_key.id
        })

      assert json_response(conn, 401)
    end

    test "rejects a disabled stream server credential", %{conn: conn} do
      %{application: application, api_key: api_key, secret: secret, public_key: public_key} =
        assigned_server_with_key()

      {:ok, key} = StreamServers.disable_stream_server_api_key(api_key.id)
      assert key.enabled == false

      conn =
        request(conn, secret, %{
          "application_id" => application.id,
          "public_key_id" => public_key.id
        })

      assert json_response(conn, 401)
    end

    test "rejects a valid application (aak_) credential", %{conn: conn} do
      %{application: application, public_key: public_key} = assigned_server_with_key()
      {_app_key, aak_secret} = api_key_with_secret_fixture(application)

      conn =
        request(conn, aak_secret, %{
          "application_id" => application.id,
          "public_key_id" => public_key.id
        })

      assert json_response(conn, 401)
    end

    test "rejects malformed or missing params" do
      %{application: application, secret: secret, public_key: public_key} =
        assigned_server_with_key()

      for params <- [
            %{"application_id" => "not-a-uuid", "public_key_id" => public_key.id},
            %{"application_id" => application.id, "public_key_id" => "not-a-uuid"},
            %{"public_key_id" => public_key.id},
            %{"application_id" => application.id},
            %{}
          ] do
        conn =
          Phoenix.ConnTest.build_conn()
          |> request(secret, params)

        assert json_response(conn, 400)
      end
    end

    test "rejects a server not assigned to the application", %{conn: conn} do
      %{application: application, public_key: public_key} = assigned_server_with_key()
      {_key, other_secret} = stream_server_api_key_with_secret_fixture(stream_server_fixture())

      conn =
        request(conn, other_secret, %{
          "application_id" => application.id,
          "public_key_id" => public_key.id
        })

      assert json_response(conn, 403)
    end

    test "returns 404 for an unknown public key id", %{conn: conn} do
      %{application: application, secret: secret} = assigned_server_with_key()

      conn =
        request(conn, secret, %{
          "application_id" => application.id,
          "public_key_id" => Ecto.UUID.generate()
        })

      assert json_response(conn, 404)
    end

    test "returns 404 for a key belonging to a different application", %{conn: conn} do
      %{secret: secret, application: application} = assigned_server_with_key()
      other_key = stream_server_public_key_fixture(application_fixture())

      conn =
        request(conn, secret, %{
          "application_id" => application.id,
          "public_key_id" => other_key.id
        })

      assert json_response(conn, 404)
    end

    test "returns 404 for a disabled key", %{conn: conn} do
      %{application: application, secret: secret, public_key: public_key} =
        assigned_server_with_key()

      {:ok, _key} = Applications.disable_stream_server_public_key(public_key.id)

      conn =
        request(conn, secret, %{
          "application_id" => application.id,
          "public_key_id" => public_key.id
        })

      assert json_response(conn, 404)
    end

    test "returns 404 for a disabled application", %{conn: conn} do
      %{application: application, secret: secret, public_key: public_key} =
        assigned_server_with_key()

      {:ok, _app} = Applications.disable_application(application.id)

      conn =
        request(conn, secret, %{
          "application_id" => application.id,
          "public_key_id" => public_key.id
        })

      assert json_response(conn, 404)
    end

    test "returns 404 for an unknown application", %{conn: conn} do
      %{secret: secret, public_key: public_key} = assigned_server_with_key()

      conn =
        request(conn, secret, %{
          "application_id" => Ecto.UUID.generate(),
          "public_key_id" => public_key.id
        })

      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end
  end
end
