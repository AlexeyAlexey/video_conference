defmodule VideoConference.StreamServerAdminPortal.Applications.ConnectionInfoTest do
  use VideoConference.DataCase, async: false

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.StreamServers

  import VideoConference.StreamServerAdminPortalFixtures

  defp assign(server, application) do
    {:ok, _} = StreamServers.assign_application(server.id, application.id)
    server
  end

  describe "connection_info/1" do
    test "returns an entry per requested code in request order" do
      application = application_fixture()

      de =
        %{"country" => "de", "cert_hash" => "abc"}
        |> stream_server_fixture()
        |> assign(application)

      us =
        %{"country" => "us"}
        |> stream_server_fixture()
        |> assign(application)

      assert {:ok, info} =
               Applications.connection_info(
                 application_id: application.id,
                 country_codes: ["de", "us"]
               )

      assert info == [
               %{country_code: "de", url: "https://" <> de.host, cert_hash: "abc"},
               %{country_code: "us", url: "https://" <> us.host}
             ]
    end

    test "preserves duplicate country_codes" do
      application = application_fixture()
      us = %{"country" => "us"} |> stream_server_fixture() |> assign(application)

      assert {:ok, info} =
               Applications.connection_info(
                 application_id: application.id,
                 country_codes: ["us", "us", "us"]
               )

      assert info ==
               List.duplicate(
                 %{country_code: "us", url: "https://" <> us.host},
                 3
               )
    end

    test "normalizes codes case-insensitively" do
      application = application_fixture()
      de = %{"country" => "de"} |> stream_server_fixture() |> assign(application)

      assert {:ok, info} =
               Applications.connection_info(
                 application_id: application.id,
                 country_codes: ["DE", "De"]
               )

      assert info ==
               List.duplicate(
                 %{country_code: "de", url: "https://" <> de.host},
                 2
               )
    end

    test "omits cert_hash when the selected server has none" do
      application = application_fixture()
      de = %{"country" => "de"} |> stream_server_fixture() |> assign(application)

      assert {:ok, [info]} =
               Applications.connection_info(
                 application_id: application.id,
                 country_codes: ["de"]
               )

      assert info == %{country_code: "de", url: "https://" <> de.host}
    end

    test "picks the least-loaded server per country" do
      application = application_fixture()

      busy = %{"country" => "de"} |> stream_server_fixture() |> assign(application)
      idle = %{"country" => "de"} |> stream_server_fixture() |> assign(application)

      {:ok, _} = StreamServers.update_stream_server_load(busy.id, 90)
      {:ok, _} = StreamServers.update_stream_server_load(idle.id, 5)

      assert {:ok, [%{country_code: "de", url: "https://" <> host}]} =
               Applications.connection_info(
                 application_id: application.id,
                 country_codes: ["de"]
               )

      assert host == idle.host
    end

    test "returns {:error, :unprocessable_entity, codes} for unsatisfiable countries" do
      application = application_fixture()
      _us = %{"country" => "us"} |> stream_server_fixture() |> assign(application)

      assert {:error, :unprocessable_entity, ["de"]} =
               Applications.connection_info(
                 application_id: application.id,
                 country_codes: ["us", "de", "de"]
               )
    end

    test "returns {:error, :unprocessable_entity, codes} when nothing is assigned" do
      application = application_fixture()

      assert {:error, :unprocessable_entity, ["de"]} =
               Applications.connection_info(
                 application_id: application.id,
                 country_codes: ["de"]
               )
    end

    test "returns {:ok, []} for an empty country_codes list" do
      application = application_fixture()

      assert {:ok, []} =
               Applications.connection_info(
                 application_id: application.id,
                 country_codes: []
               )
    end
  end
end
