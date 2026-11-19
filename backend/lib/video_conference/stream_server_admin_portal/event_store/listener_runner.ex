defmodule VideoConference.StreamServerAdminPortal.EventStore.ListenerRunner do
  @moduledoc """
  One supervised process per event store listener.

  On start it upserts the listener's `event_listeners` row (metadata
  comes from `module.__listener__/0`, the row carries the durable
  cursor and status) and refuses to start while the persisted status is
  `"failed"`. It then polls `EventStore.get_events/2` for the declared
  event types after `last_seen_seq`, dispatches each decoded event
  struct to `module.handle_event/1` in ascending `seq` order, and
  advances the durable cursor after every acknowledged event.

  A failed event is retried with exponential backoff (`backoff * 2^(n-1)`
  capped at `max_backoff`); raised exceptions are rescued and treated as
  failures. When the retry budget is exhausted the row is marked
  `"failed"` with `last_error` and the runner halts — children are
  `:temporary`, so it stays down until `EventStore.resume_listener/1`.
  """
  use GenServer

  require Logger

  alias VideoConference.StreamServerAdminPortal.EventStore
  alias VideoConference.StreamServerAdminPortal.EventStore.ListenerState
  alias VideoConference.StreamServerAdminPortal.Repo

  @poll_interval 1_000

  def start_link(module) do
    GenServer.start_link(__MODULE__, module, name: module)
  end

  def child_spec(module) do
    %{
      id: {__MODULE__, module},
      start: {__MODULE__, :start_link, [module]},
      restart: :temporary
    }
  end

  @impl true
  def init(module) do
    config = module.__listener__()

    case upsert_listener(config) do
      {:ok, %ListenerState{status: "failed"}} ->
        :ignore

      {:ok, listener} ->
        state = %{
          module: module,
          config: config,
          listener: listener,
          cursor: listener.last_seen_seq
        }

        {:ok, state, {:continue, :poll}}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:stop, {:invalid_listener, changeset}}
    end
  end

  @impl true
  def handle_continue(:poll, state), do: poll(state)

  @impl true
  def handle_info(:poll, state), do: poll(state)

  defp poll(state) do
    case drain(state) do
      {:ok, state} ->
        Process.send_after(self(), :poll, poll_interval())
        {:noreply, state}

      {:failed, state} ->
        {:stop, :normal, state}
    end
  end

  defp drain(state) do
    state.config.events
    |> fetch_events(state.cursor)
    |> Enum.reduce_while({:ok, state}, fn event, {:ok, acc} ->
      case deliver(acc, event) do
        {:ok, acc} -> {:cont, {:ok, acc}}
        {:failed, acc} -> {:halt, {:failed, acc}}
      end
    end)
  end

  defp fetch_events(event_types, cursor) do
    EventStore.get_events(event_types, cursor)
  rescue
    exception ->
      Logger.error(
        "event listener poll failed: " <>
          Exception.format(:error, exception, __STACKTRACE__)
      )

      []
  end

  defp deliver(state, event), do: deliver_attempt(state, event, 1)

  defp deliver_attempt(state, event, attempt) do
    case safe_handle(state.module, event.payload) do
      :ok ->
        {:ok, advance_cursor(state, event.seq)}

      {:error, reason} ->
        if attempt > state.config.retries do
          {:failed, mark_failed(state, event, reason)}
        else
          Process.sleep(backoff_delay(state.config, attempt))
          deliver_attempt(state, event, attempt + 1)
        end
    end
  end

  defp safe_handle(module, event) do
    module.handle_event(event)
  rescue
    exception -> {:error, Exception.format(:error, exception, __STACKTRACE__)}
  catch
    kind, reason -> {:error, Exception.format(kind, reason, __STACKTRACE__)}
  else
    :ok -> :ok
    {:error, reason} -> {:error, inspect(reason)}
    other -> {:error, inspect({:unexpected_return, other})}
  end

  defp backoff_delay(config, attempt) do
    min(config.backoff * Integer.pow(2, attempt - 1), config.max_backoff)
  end

  defp advance_cursor(state, seq) do
    listener =
      state.listener
      |> ListenerState.changeset(%{last_seen_seq: seq})
      |> Repo.update!()

    %{state | listener: listener, cursor: seq}
  end

  defp mark_failed(state, event, reason) do
    Logger.warning(
      "event listener #{state.config.name} marked failed on event seq #{event.seq}: #{reason}"
    )

    listener =
      state.listener
      |> ListenerState.changeset(%{
        status: "failed",
        last_error: "seq #{event.seq}: #{reason}"
      })
      |> Repo.update!()

    %{state | listener: listener}
  end

  defp upsert_listener(config) do
    %ListenerState{}
    |> ListenerState.changeset(%{name: config.name, description: config.description})
    |> Repo.insert(
      on_conflict: [set: [description: config.description]],
      conflict_target: :name,
      returning: true
    )
  end

  defp poll_interval do
    :video_conference
    |> Application.get_env(:stream_server_admin_portal, [])
    |> Keyword.get(:event_listener_poll_interval, @poll_interval)
  end
end
