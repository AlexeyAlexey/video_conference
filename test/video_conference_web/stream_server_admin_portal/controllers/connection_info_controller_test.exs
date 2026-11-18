defmodule VideoConferenceWeb.StreamServerAdminPortal.Applications.ConnectionInfoControllerTest do
  use VideoConferenceWeb.ConnCase, async: false

  import VideoConference.StreamServerAdminPortalFixtures

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.StreamServers

  @path "/stream-server-admin/api/application/connection-info"

  defp request(conn, secret, params) do
    conn
    |> put_req_header("x-api-key", secret)
    |> get(@path, params)
  end

  defp application_with_secret do
    application = application_fixture()
    {_key, secret} = api_key_with_secret_fixture(application)
    {application, secret}
  end

  defp assigned_server(application, attrs, load \\ 0) do
    server = stream_server_fixture(attrs)
    {:ok, server} = StreamServers.update_stream_server_load(server.id, load)
    {:ok, _} = StreamServers.assign_application(server.id, application.id)
    server
  end

  describe "GET /stream-server-admin/api/application/connection-info" do
    test "returns a connection info entry per requested code", %{conn: conn} do
      {application, secret} = application_with_secret()
      server = assigned_server(application, %{"country" => "de", "cert_hash" => "abc123"})

      conn = request(conn, secret, %{"country_codes" => ["de"]})

      assert json_response(conn, 200) == [
               %{
                 "country_code" => "de",
                 "url" => "https://" <> server.host,
                 "cert_hash" => "abc123"
               }
             ]
    end

    test "preserves request order and duplicates", %{conn: conn} do
      {application, secret} = application_with_secret()
      de = assigned_server(application, %{"country" => "de"})
      us = assigned_server(application, %{"country" => "us"})

      conn = request(conn, secret, %{"country_codes" => ["us", "de", "us"]})

      assert json_response(conn, 200) == [
               %{"country_code" => "us", "url" => "https://" <> us.host},
               %{"country_code" => "de", "url" => "https://" <> de.host},
               %{"country_code" => "us", "url" => "https://" <> us.host}
             ]
    end

    test "rejects a request without an X-API-Key header", %{conn: conn} do
      conn = get(conn, @path, %{"country_codes" => ["de"]})

      assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
    end

    test "rejects a valid stream server (ssak_) credential", %{conn: conn} do
      {_key, ssak_secret} = stream_server_api_key_with_secret_fixture(stream_server_fixture())

      conn = request(conn, ssak_secret, %{"country_codes" => ["de"]})

      assert json_response(conn, 401) == %{"errors" => %{"detail" => "Unauthorized"}}
    end

    test "rejects a disabled application credential", %{conn: conn} do
      application = application_fixture()
      {key, secret} = api_key_with_secret_fixture(application)
      {:ok, _} = Applications.disable_api_key(key.id)

      conn = request(conn, secret, %{"country_codes" => ["de"]})

      assert json_response(conn, 401)
    end

    test "rejects a disabled application", %{conn: conn} do
      {application, secret} = application_with_secret()
      {:ok, _} = Applications.disable_application(application.id)

      conn = request(conn, secret, %{"country_codes" => ["de"]})

      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end

    test "rejects malformed or missing country_codes params" do
      {_application, secret} = application_with_secret()

      for params <- [
            %{},
            %{"country_codes" => "de"},
            %{"country_codes" => %{"code" => "de"}},
            %{"country_codes" => []},
            %{"country_codes" => ["us", "gb", "de", "fr", "jp"]},
            %{"country_codes" => [1]},
            %{"country_codes" => [nil]},
            %{"country_codes" => ["any"]},
            %{"country_codes" => ["usa"]},
            %{"country_codes" => ["d"]},
            %{"country_codes" => ["d1"]}
          ] do
        conn =
          Phoenix.ConnTest.build_conn()
          |> request(secret, params)

        assert json_response(conn, 400) == %{"errors" => %{"detail" => "Bad Request"}}
      end
    end

    test "counts only distinct codes toward the limit", %{conn: conn} do
      {application, secret} = application_with_secret()
      server = assigned_server(application, %{"country" => "de"})

      conn =
        request(conn, secret, %{"country_codes" => ["de", "de", "de", "de", "de"]})

      entry = %{"country_code" => "de", "url" => "https://" <> server.host}
      assert json_response(conn, 200) == List.duplicate(entry, 5)
    end

    test "country_codes are case insensitive", %{conn: conn} do
      {application, secret} = application_with_secret()
      de = assigned_server(application, %{"country" => "de"})
      us = assigned_server(application, %{"country" => "us"})

      conn = request(conn, secret, %{"country_codes" => ["US", "De"]})

      assert json_response(conn, 200) == [
               %{"country_code" => "us", "url" => "https://" <> us.host},
               %{"country_code" => "de", "url" => "https://" <> de.host}
             ]
    end

    test "selects the least-loaded assigned server for a country", %{conn: conn} do
      {application, secret} = application_with_secret()
      _busy = assigned_server(application, %{"name" => "a-busy", "country" => "de"}, 40)
      idle = assigned_server(application, %{"name" => "z-idle", "country" => "de"}, 10)

      conn = request(conn, secret, %{"country_codes" => ["de"]})

      assert json_response(conn, 200) == [
               %{"country_code" => "de", "url" => "https://" <> idle.host}
             ]
    end

    test "each code resolves independently", %{conn: conn} do
      {application, secret} = application_with_secret()
      de = assigned_server(application, %{"country" => "de"})
      us = assigned_server(application, %{"country" => "us"})

      conn = request(conn, secret, %{"country_codes" => ["de", "us"]})

      assert json_response(conn, 200) == [
               %{"country_code" => "de", "url" => "https://" <> de.host},
               %{"country_code" => "us", "url" => "https://" <> us.host}
             ]
    end

    test "returns 422 naming the codes with no assigned server", %{conn: conn} do
      {application, secret} = application_with_secret()
      _us = assigned_server(application, %{"country" => "us"})

      conn = request(conn, secret, %{"country_codes" => ["us", "de", "de", "fr"]})

      assert %{"errors" => %{"detail" => "No stream server available", "country_codes" => codes}} =
               json_response(conn, 422)

      assert Enum.sort(codes) == ["de", "fr"]
    end

    test "returns 422 when no servers are assigned at all", %{conn: conn} do
      {_application, secret} = application_with_secret()

      conn = request(conn, secret, %{"country_codes" => ["de"]})

      assert json_response(conn, 422) == %{
               "errors" => %{
                 "detail" => "No stream server available",
                 "country_codes" => ["de"]
               }
             }
    end

    test "omits cert_hash when the selected server has none", %{conn: conn} do
      {application, secret} = application_with_secret()
      server = assigned_server(application, %{"country" => "de"})

      conn = request(conn, secret, %{"country_codes" => ["de"]})

      assert [%{"country_code" => "de"} = info] = json_response(conn, 200)
      assert info == %{"country_code" => "de", "url" => "https://" <> server.host}
      refute Map.has_key?(info, "cert_hash")
    end
  end
end
