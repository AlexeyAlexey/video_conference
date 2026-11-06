defmodule VideoConference.StreamServerAdminPortal.EventStoreTest do
  use VideoConference.DataCase, async: false

  alias Ecto.Multi
  alias VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyAddedEvent
  alias VideoConference.StreamServerAdminPortal.EventStore
  alias VideoConference.StreamServerAdminPortal.EventStore.{Event, Stream}
  alias VideoConference.StreamServerAdminPortal.Repo, as: PortalRepo

  defp event_fixture(attrs \\ %{}) do
    Enum.into(attrs, %{
      stream_id: Ecto.UUID.generate(),
      application_id: Ecto.UUID.generate(),
      name: "key",
      key: "public-key",
      enabled: true,
      description: nil
    })
    |> then(&struct!(StreamServerPublicKeyAddedEvent, &1))
  end

  defp event_type, do: inspect(StreamServerPublicKeyAddedEvent)

  describe "append/1" do
    test "persists events with increasing seq on a created stream" do
      stream_id = Ecto.UUID.generate()
      first = event_fixture(%{stream_id: stream_id})
      second = event_fixture(%{stream_id: stream_id})

      assert {:ok, _} = PortalRepo.transaction(EventStore.append([first, second]))

      stored = PortalRepo.all(from(e in Event, order_by: [asc: e.seq]))

      assert [one, two] = stored
      assert one.seq < two.seq
      assert one.stream_id == stream_id
      assert one.version == 1
      assert two.version == 2
      assert one.event_type == event_type()
      assert %DateTime{} = one.added_at
      assert :erlang.binary_to_term(one.payload) == first

      stream = PortalRepo.get_by!(Stream, stream_id: stream_id)
      assert stream.version == 2
      assert %DateTime{} = stream.created_at
      assert stream.deleted_at == nil
    end

    test "assigns contiguous versions per stream across transactions" do
      stream_id = Ecto.UUID.generate()

      assert {:ok, _} =
               PortalRepo.transaction(EventStore.append([event_fixture(%{stream_id: stream_id})]))

      assert {:ok, _} =
               PortalRepo.transaction(EventStore.append([event_fixture(%{stream_id: stream_id})]))

      assert PortalRepo.get_by!(Stream, stream_id: stream_id).version == 2

      assert [%Event{version: 1}, %Event{version: 2}] =
               PortalRepo.all(from(e in Event, order_by: [asc: e.version]))
    end

    test "counts versions independently per stream" do
      first = event_fixture()
      second = event_fixture()

      assert {:ok, _} = PortalRepo.transaction(EventStore.append([first, second]))

      assert PortalRepo.get_by!(Stream, stream_id: first.stream_id).version == 1
      assert PortalRepo.get_by!(Stream, stream_id: second.stream_id).version == 1

      assert Enum.map(PortalRepo.all(Event), & &1.version) == [1, 1]
    end

    test "counts all appended events on the reserved $all stream" do
      first = event_fixture()
      second = event_fixture()

      assert {:ok, _} = PortalRepo.transaction(EventStore.append([first, second]))

      all = PortalRepo.get!(Stream, 0)
      assert all.stream_id == "$all"
      assert all.version == 2

      assert PortalRepo.aggregate(Event, :count) == all.version
    end

    test "rejects an event without a stream_id" do
      for stream_id <- [nil, ""] do
        event = event_fixture(%{stream_id: stream_id})

        assert {:error, _op, %Ecto.Changeset{} = changeset, _} =
                 PortalRepo.transaction(EventStore.append([event]))

        assert %{stream_id: ["can't be blank"]} = errors_on(changeset)
      end

      assert PortalRepo.aggregate(Event, :count) == 0
      assert PortalRepo.get!(Stream, 0).version == 0
    end

    test "rejects the reserved $all stream id" do
      event = event_fixture(%{stream_id: "$all"})

      assert {:error, _op, %Ecto.Changeset{} = changeset, _} =
               PortalRepo.transaction(EventStore.append([event]))

      assert %{stream_id: ["is reserved"]} = errors_on(changeset)
      assert PortalRepo.aggregate(Event, :count) == 0
      assert PortalRepo.get!(Stream, 0).version == 0
    end
  end

  describe "append/2" do
    test "extends an existing multi" do
      event = event_fixture()

      multi =
        Multi.new()
        |> Multi.put(:marker, "value")
        |> EventStore.append([event])

      assert {:ok, %{marker: "value"}} = PortalRepo.transaction(multi)
      assert PortalRepo.exists?(from(e in Event, where: e.stream_id == ^event.stream_id))
    end

    test "can be called twice on the same multi" do
      stream_id = Ecto.UUID.generate()
      first = event_fixture(%{stream_id: stream_id})
      second = event_fixture(%{stream_id: stream_id})

      multi =
        Multi.new()
        |> EventStore.append([first])
        |> EventStore.append([second])

      assert {:ok, _} = PortalRepo.transaction(multi)

      assert [%Event{version: 1}, %Event{version: 2}] =
               PortalRepo.all(from(e in Event, order_by: [asc: e.version]))
    end

    test "rolls back the event and stream bumps when the transaction fails" do
      event = event_fixture()

      multi =
        Multi.new()
        |> EventStore.append([event])
        |> Multi.error(:failure, :boom)

      assert {:error, :failure, :boom, _} = PortalRepo.transaction(multi)
      refute PortalRepo.exists?(from(e in Event, where: e.stream_id == ^event.stream_id))
      refute PortalRepo.exists?(from(s in Stream, where: s.stream_id == ^event.stream_id))
      assert PortalRepo.get!(Stream, 0).version == 0
    end
  end

  describe "decode_payload/1" do
    test "round-trips an event struct through term_to_binary" do
      event = event_fixture()

      assert EventStore.decode_payload(:erlang.term_to_binary(event)) == event
    end
  end

  describe "get_events/2" do
    test "filters by event type names" do
      event = event_fixture()
      other = event_fixture()

      assert {:ok, _} = PortalRepo.transaction(EventStore.append([event]))

      PortalRepo.insert!(%Event{
        stream_id: other.stream_id,
        version: 1,
        event_type: "Other.Module",
        payload: :erlang.term_to_binary(other)
      })

      assert [%Event{stream_id: stream_id}] = EventStore.get_events([event_type()], 0)
      assert stream_id == event.stream_id

      assert [%Event{event_type: "Other.Module"}] =
               EventStore.get_events(["Other.Module"], 0)
    end

    test "filters by seq cursor" do
      first = event_fixture()
      second = event_fixture()

      assert {:ok, _} = PortalRepo.transaction(EventStore.append([first, second]))

      [%Event{seq: first_seq} | _] = EventStore.get_events([event_type()], 0)

      assert [%Event{stream_id: stream_id}] = EventStore.get_events([event_type()], first_seq)
      assert stream_id == second.stream_id
    end

    test "returns events ordered by seq with decoded payloads" do
      first = event_fixture()
      second = event_fixture()

      assert {:ok, _} = PortalRepo.transaction(EventStore.append([first, second]))

      assert [one, two] = EventStore.get_events([event_type()], 0)
      assert one.seq < two.seq
      assert one.payload == first
      assert two.payload == second
    end

    test "returns an empty list when nothing matches" do
      assert EventStore.get_events(["Missing.Module"], 0) == []

      event = event_fixture()
      assert {:ok, _} = PortalRepo.transaction(EventStore.append([event]))
      assert EventStore.get_events(["Missing.Module"], 0) == []
    end
  end

  describe "duplicate stream position" do
    test "fails with a uniqueness error and stores no second event" do
      event = event_fixture()

      assert {:ok, _} = PortalRepo.transaction(EventStore.append([event]))

      assert_raise Ecto.ConstraintError, fn ->
        PortalRepo.insert!(%Event{
          stream_id: event.stream_id,
          version: 1,
          event_type: "Other.Module",
          payload: :erlang.term_to_binary(event_fixture())
        })
      end

      assert PortalRepo.aggregate(
               from(
                 e in Event,
                 where: e.stream_id == ^event.stream_id and e.version == 1
               ),
               :count
             ) == 1
    end
  end
end
