defmodule VideoConference.StreamServerAdminPortal.EventStore.ListenerStateTest do
  use VideoConference.DataCase, async: false

  alias VideoConference.StreamServerAdminPortal.EventStore.ListenerState
  alias VideoConference.StreamServerAdminPortal.Repo, as: PortalRepo

  defp listener_state_fixture(attrs \\ %{}) do
    {:ok, listener_state} =
      %ListenerState{}
      |> ListenerState.changeset(
        Enum.into(attrs, %{
          name: "listener-#{System.unique_integer([:positive])}",
          description: "a listener"
        })
      )
      |> PortalRepo.insert()

    listener_state
  end

  describe "changeset/2" do
    test "requires a name" do
      changeset = ListenerState.changeset(%ListenerState{}, %{})

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects an empty name" do
      changeset = ListenerState.changeset(%ListenerState{}, %{name: ""})

      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "enforces unique names" do
      listener_state = listener_state_fixture()

      assert {:error, changeset} =
               %ListenerState{}
               |> ListenerState.changeset(%{name: listener_state.name})
               |> PortalRepo.insert()

      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "accepts ok and failed statuses" do
      for status <- ["ok", "failed"] do
        changeset =
          ListenerState.changeset(%ListenerState{}, %{name: "listener", status: status})

        assert changeset.valid?
      end
    end

    test "rejects other statuses" do
      changeset =
        ListenerState.changeset(%ListenerState{}, %{name: "listener", status: "paused"})

      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "rejects a negative last_seen_seq" do
      changeset =
        ListenerState.changeset(%ListenerState{}, %{name: "listener", last_seen_seq: -1})

      assert %{last_seen_seq: [_ | _]} = errors_on(changeset)
    end

    test "defaults status to ok and last_seen_seq to 0" do
      listener_state = listener_state_fixture()

      assert listener_state.status == "ok"
      assert listener_state.last_seen_seq == 0
      assert listener_state.last_error == nil
    end
  end
end
