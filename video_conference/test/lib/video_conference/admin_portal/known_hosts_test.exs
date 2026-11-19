defmodule VideoConference.AdminPortal.KnownHostsTest do
  use VideoConference.DataCase, async: false

  alias VideoConference.AdminPortal.KnownHosts
  alias VideoConference.AdminPortal.KnownHosts.KnownHost

  import VideoConference.KnownHostsFixtures

  describe "list_known_hosts/0" do
    test "returns all known hosts including the seeded current host" do
      known_host = known_host_fixture()

      hosts = KnownHosts.list_known_hosts()
      ids = Enum.map(hosts, & &1.id)

      assert known_host.id in ids
      assert current_host_fixture().id in ids
    end

    test "lists the current host first" do
      known_host_fixture()

      assert [%KnownHost{current_host: true} | _] = KnownHosts.list_known_hosts()
    end
  end

  describe "get_known_host!/1" do
    test "returns the host with the given id" do
      known_host = known_host_fixture()
      assert KnownHosts.get_known_host!(known_host.id).id == known_host.id
    end

    test "raises for an unknown id" do
      assert_raise Ecto.NoResultsError, fn -> KnownHosts.get_known_host!(0) end
    end
  end

  describe "create_known_host/1" do
    test "persists a host with default flags and empty settings" do
      name = unique_known_host_name()

      assert {:ok, %KnownHost{} = known_host} =
               KnownHosts.create_known_host(%{"name" => name})

      assert known_host.name == name
      assert known_host.enabled == true
      assert known_host.current_host == false
      assert known_host.settings == %{}
    end

    test "requires a name" do
      assert {:error, changeset} = KnownHosts.create_known_host(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects a duplicate name" do
      known_host = known_host_fixture()

      assert {:error, changeset} = KnownHosts.create_known_host(%{"name" => known_host.name})
      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "rejects a second current host" do
      assert {:error, changeset} =
               KnownHosts.create_known_host(%{
                 "name" => unique_known_host_name(),
                 "current_host" => true
               })

      assert %{current_host: [_ | _]} = errors_on(changeset)
      assert Repo.exists?(from(k in KnownHost, where: k.current_host == true))
    end
  end

  describe "update_known_host/2" do
    test "updates a non-current host" do
      known_host = known_host_fixture()

      assert {:ok, %KnownHost{} = updated} =
               KnownHosts.update_known_host(known_host, %{
                 "name_alias" => "new alias",
                 "description" => "new description",
                 "host" => "10.0.0.1",
                 "enabled" => false
               })

      assert updated.name_alias == "new alias"
      assert updated.description == "new description"
      assert updated.host == "10.0.0.1"
      assert updated.enabled == false
    end

    test "rejects renaming to a taken name" do
      known_host = known_host_fixture()
      other = known_host_fixture()

      assert {:error, changeset} =
               KnownHosts.update_known_host(known_host, %{"name" => other.name})

      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "rejects setting current_host on a second row" do
      known_host = known_host_fixture()

      assert {:error, changeset} =
               KnownHosts.update_known_host(known_host, %{"current_host" => true})

      assert %{current_host: [_ | _]} = errors_on(changeset)
    end

    test "rejects disabling the current host" do
      current_host = current_host_fixture()

      assert {:error, changeset} =
               KnownHosts.update_known_host(current_host, %{"enabled" => false})

      assert %{enabled: [_ | _]} = errors_on(changeset)
      assert Repo.get!(KnownHost, current_host.id).enabled == true
    end

    test "rejects clearing current_host on the current host" do
      current_host = current_host_fixture()

      assert {:error, changeset} =
               KnownHosts.update_known_host(current_host, %{"current_host" => false})

      assert %{current_host: [_ | _]} = errors_on(changeset)
      assert Repo.get!(KnownHost, current_host.id).current_host == true
    end

    test "updates the current host's editable fields" do
      current_host = current_host_fixture()

      assert {:ok, %KnownHost{} = updated} =
               KnownHosts.update_known_host(current_host, %{
                 "name_alias" => "us",
                 "description" => "this instance",
                 "host" => "127.0.0.1:4433"
               })

      assert updated.name_alias == "us"
      assert updated.current_host == true
      assert updated.enabled == true
    end
  end

  describe "delete_known_host/1" do
    test "deletes a non-current host" do
      known_host = known_host_fixture()

      assert {:ok, %KnownHost{}} = KnownHosts.delete_known_host(known_host)
      refute Repo.exists?(from(k in KnownHost, where: k.id == ^known_host.id))
    end

    test "refuses to delete the current host" do
      current_host = current_host_fixture()

      assert {:error, changeset} = KnownHosts.delete_known_host(current_host)
      assert %{current_host: [_ | _]} = errors_on(changeset)
      assert Repo.exists?(from(k in KnownHost, where: k.id == ^current_host.id))
    end
  end

  describe "change_known_host/2" do
    test "returns a changeset" do
      known_host = known_host_fixture()
      assert %Ecto.Changeset{data: %KnownHost{}} = KnownHosts.change_known_host(known_host)
    end
  end
end
