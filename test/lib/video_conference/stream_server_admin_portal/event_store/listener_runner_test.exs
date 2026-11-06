defmodule VideoConference.StreamServerAdminPortal.EventStore.ListenerRunnerTest do
  use VideoConference.DataCase, async: false

  alias VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyAddedEvent
  alias VideoConference.StreamServerAdminPortal.EventStore

  alias VideoConference.StreamServerAdminPortal.EventStore.{
    Event,
    ListenerRunner,
    ListenerState,
    ListenersSupervisor
  }

  alias VideoConference.StreamServerAdminPortal.Repo, as: PortalRepo
  alias VideoConference.StreamServerAdminPortalFixtures

  defmodule ListenerHelper do
    def notify(message) do
      if pid = Application.get_env(:video_conference, :test_listener_inbox) do
        send(pid, message)
      end

      :ok
    end

    def result do
      Application.get_env(:video_conference, :test_listener_result, :ok)
    end
  end

  defmodule RecordingListener do
    use VideoConference.StreamServerAdminPortal.EventStore.Listener,
      name: "recording-listener",
      description: "records delivered events",
      events: [
        VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyAddedEvent
      ],
      retries: 0

    @impl true
    def handle_event(event) do
      ListenerHelper.notify({:recording_listener, event})
      ListenerHelper.result()
    end
  end

  defmodule RaisingListener do
    use VideoConference.StreamServerAdminPortal.EventStore.Listener,
      name: "raising-listener",
      description: "always raises",
      events: [
        VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyAddedEvent
      ],
      retries: 2,
      backoff: 25,
      max_backoff: 50

    @impl true
    def handle_event(_event) do
      ListenerHelper.notify(:raising_attempt)
      raise "boom"
    end
  end

  defmodule OtherBootListener do
    use VideoConference.StreamServerAdminPortal.EventStore.Listener,
      name: "other-boot-listener",
      events: [
        VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyAddedEvent
      ]

    @impl true
    def handle_event(_event), do: :ok
  end

  setup do
    Application.put_env(:video_conference, :test_listener_inbox, self())

    on_exit(fn ->
      for {_, pid, _, _} <- DynamicSupervisor.which_children(ListenersSupervisor) do
        DynamicSupervisor.terminate_child(ListenersSupervisor, pid)
      end

      Application.delete_env(:video_conference, :test_listener_inbox)
      Application.delete_env(:video_conference, :test_listener_result)
      put_event_listeners([])
    end)

    :ok
  end

  defp put_event_listeners(modules) do
    config = Application.get_env(:video_conference, :stream_server_admin_portal, [])

    Application.put_env(
      :video_conference,
      :stream_server_admin_portal,
      Keyword.put(config, :event_listeners, modules)
    )
  end

  defp append_event(attrs \\ %{}) do
    event =
      attrs
      |> Enum.into(%{
        stream_id: Ecto.UUID.generate(),
        application_id: Ecto.UUID.generate(),
        name: "key",
        key: "public-key",
        enabled: true,
        description: nil
      })
      |> then(&struct!(StreamServerPublicKeyAddedEvent, &1))

    {:ok, _} = PortalRepo.transaction(EventStore.append([event]))
    event
  end

  defp last_seq do
    EventStore.get_events([inspect(StreamServerPublicKeyAddedEvent)], 0)
    |> List.last()
    |> Map.fetch!(:seq)
  end

  defp listener_state(name), do: PortalRepo.get_by!(ListenerState, name: name)

  defp start_runner(module) do
    DynamicSupervisor.start_child(ListenersSupervisor, {ListenerRunner, module})
  end

  defp eventually(assertion, attempts \\ 50)

  defp eventually(assertion, 0), do: assertion.()

  defp eventually(assertion, attempts) do
    assertion.()
  rescue
    ExUnit.AssertionError ->
      Process.sleep(20)
      eventually(assertion, attempts - 1)
  end

  describe "runner start" do
    test "upserts the listener row on init and reuses an existing row" do
      {:ok, pid} = start_runner(RecordingListener)

      listener = listener_state("recording-listener")
      assert listener.description == "records delivered events"
      assert listener.status == "ok"
      assert listener.last_seen_seq == 0

      PortalRepo.update!(
        ListenerState.changeset(listener, %{last_seen_seq: 7, description: "stale"})
      )

      DynamicSupervisor.terminate_child(ListenersSupervisor, pid)

      {:ok, _pid} = start_runner(RecordingListener)

      assert %{last_seen_seq: 7, description: "records delivered events"} =
               listener_state("recording-listener")
    end

    test "refuses to start while the listener row is marked failed" do
      PortalRepo.insert!(
        ListenerState.changeset(%ListenerState{}, %{
          name: "recording-listener",
          status: "failed",
          last_error: "boom"
        })
      )

      assert :ignore = start_runner(RecordingListener)
      assert Process.whereis(RecordingListener) == nil
    end
  end

  describe "dispatch" do
    test "delivers matching events after the cursor in ascending seq order" do
      append_event(%{name: "first"})
      append_event(%{name: "second"})

      PortalRepo.insert!(%Event{
        stream_id: Ecto.UUID.generate(),
        version: 1,
        event_type: "Not.Subscribed",
        payload:
          :erlang.term_to_binary(%StreamServerPublicKeyAddedEvent{
            stream_id: Ecto.UUID.generate(),
            name: "other"
          })
      })

      {:ok, _pid} = start_runner(RecordingListener)

      assert_receive {:recording_listener, %StreamServerPublicKeyAddedEvent{name: "first"}}
      assert_receive {:recording_listener, %StreamServerPublicKeyAddedEvent{name: "second"}}
      refute_receive {:recording_listener, %StreamServerPublicKeyAddedEvent{name: "other"}}
    end

    test "advances the cursor only after a successful delivery" do
      first = append_event(%{name: "first"})
      {:ok, _pid} = start_runner(RecordingListener)

      assert_receive {:recording_listener, %StreamServerPublicKeyAddedEvent{name: "first"}}

      seq = last_seq()
      eventually(fn -> assert listener_state("recording-listener").last_seen_seq == seq end)

      Application.put_env(:video_conference, :test_listener_result, {:error, :boom})
      second = append_event(%{name: "second"})

      assert_receive {:recording_listener, %StreamServerPublicKeyAddedEvent{name: "second"}}

      eventually(fn ->
        listener = listener_state("recording-listener")
        assert listener.last_seen_seq == seq
        assert listener.status == "failed"
      end)

      assert first.stream_id != second.stream_id
    end
  end

  describe "retries" do
    test "retries a raised handler the configured number of times with backoff" do
      append_event()
      {:ok, _pid} = start_runner(RaisingListener)

      start = System.monotonic_time(:millisecond)
      assert_receive :raising_attempt
      assert_receive :raising_attempt
      assert_receive :raising_attempt
      refute_receive :raising_attempt

      eventually(fn -> assert listener_state("raising-listener").status == "failed" end)

      elapsed = System.monotonic_time(:millisecond) - start
      # backoff 25ms then capped 50ms between the three attempts
      assert elapsed >= 70

      listener = listener_state("raising-listener")
      assert listener.last_error =~ "boom"
      assert listener.last_seen_seq == 0
    end
  end

  describe "failure" do
    test "marks the listener failed, halts the runner, and stops delivering" do
      Application.put_env(:video_conference, :test_listener_result, {:error, :boom})

      append_event()
      {:ok, pid} = start_runner(RecordingListener)
      ref = Process.monitor(pid)

      assert_receive {:recording_listener, %StreamServerPublicKeyAddedEvent{}}
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      refute Process.alive?(pid)

      listener = listener_state("recording-listener")
      assert listener.status == "failed"
      assert listener.last_error =~ ":boom"

      append_event(%{name: "never-delivered"})

      refute_receive {:recording_listener,
                      %StreamServerPublicKeyAddedEvent{name: "never-delivered"}}
    end
  end

  describe "supervision" do
    test "the app boots the ListenersSupervisor and starts configured listeners" do
      assert Process.whereis(ListenersSupervisor)

      put_event_listeners([RecordingListener])
      ListenersSupervisor.start_configured_listeners()

      assert Process.whereis(RecordingListener)
      assert DynamicSupervisor.count_children(ListenersSupervisor).active == 1
    end

    test "a failed listener row is not started while ok listeners start" do
      PortalRepo.insert!(
        ListenerState.changeset(%ListenerState{}, %{
          name: "recording-listener",
          status: "failed",
          last_error: "boom"
        })
      )

      put_event_listeners([RecordingListener, OtherBootListener])

      ListenersSupervisor.start_configured_listeners()

      assert Process.whereis(RecordingListener) == nil
      assert Process.whereis(OtherBootListener)
      assert DynamicSupervisor.count_children(ListenersSupervisor).active == 1
    end
  end

  describe "resume_listener/1" do
    test "returns :not_found for an unknown listener" do
      assert {:error, :not_found} = EventStore.resume_listener("missing")
    end

    test "returns :not_found when no configured module declares the name" do
      PortalRepo.insert!(
        ListenerState.changeset(%ListenerState{}, %{
          name: "recording-listener",
          status: "failed"
        })
      )

      assert {:error, :not_found} = EventStore.resume_listener("recording-listener")
    end

    test "returns :not_failed for a listener that is not failed" do
      PortalRepo.insert!(ListenerState.changeset(%ListenerState{}, %{name: "recording-listener"}))

      assert {:error, :not_failed} = EventStore.resume_listener("recording-listener")
    end

    test "clears the failure and retries the failed event first" do
      Application.put_env(:video_conference, :test_listener_result, {:error, :boom})

      failed_event = append_event(%{name: "poison"})
      {:ok, _pid} = start_runner(RecordingListener)
      assert_receive {:recording_listener, %StreamServerPublicKeyAddedEvent{name: "poison"}}

      eventually(fn ->
        assert listener_state("recording-listener").status == "failed"
      end)

      assert DynamicSupervisor.count_children(ListenersSupervisor).active == 0

      Application.put_env(:video_conference, :test_listener_result, :ok)
      put_event_listeners([RecordingListener])
      append_event(%{name: "later"})

      assert :ok = EventStore.resume_listener("recording-listener")

      listener = listener_state("recording-listener")
      assert listener.status == "ok"
      assert listener.last_error == nil

      assert_receive {:recording_listener, %StreamServerPublicKeyAddedEvent{name: "poison"}}
      assert_receive {:recording_listener, %StreamServerPublicKeyAddedEvent{name: "later"}}

      eventually(fn ->
        assert listener_state("recording-listener").last_seen_seq == last_seq()
      end)

      assert failed_event.name == "poison"
    end
  end

  describe "end to end" do
    test "creating a stream server public key delivers the event and advances the cursor" do
      {:ok, _pid} = start_runner(RecordingListener)

      application = StreamServerAdminPortalFixtures.application_fixture()
      key = StreamServerAdminPortalFixtures.stream_server_public_key_fixture(application)

      assert_receive {:recording_listener, %StreamServerPublicKeyAddedEvent{stream_id: stream_id}}

      assert stream_id == key.id

      %Event{seq: seq} = PortalRepo.get_by!(Event, stream_id: key.id)

      eventually(fn ->
        assert listener_state("recording-listener").last_seen_seq == seq
      end)
    end
  end
end
