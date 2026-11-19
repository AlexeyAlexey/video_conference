defmodule VideoConference.StreamServerAdminPortal.EventStore do
  @moduledoc """
  Append-only event store for the stream server admin portal.

  Events are appended through `append/1` and `append/2`, which return an
  `Ecto.Multi` so an event and the change it describes commit (or roll
  back) in the same transaction. Each event carries a non-empty
  `stream_id` identifying the stream it belongs to; the store assigns
  it the next contiguous per-stream `version` by incrementing the
  stream's `version` counter in `streams` inside the same transaction.
  The reserved `"$all"` stream counts every appended event — its
  `version` tracks the global event count. `get_events/2` reads stored
  events back in `seq` order for future subscribers.
  """

  import Ecto.Query, warn: false

  alias Ecto.{Changeset, Multi}

  alias VideoConference.StreamServerAdminPortal.EventStore.{
    Event,
    ListenerRunner,
    ListenerState,
    ListenersSupervisor,
    Stream
  }

  alias VideoConference.StreamServerAdminPortal.Repo

  @all_stream "$all"

  @doc """
  Returns an `Ecto.Multi` appending each event struct to its stream,
  suitable for `Ecto.Multi.merge/2`.
  """
  def append(events) when is_list(events), do: append(Multi.new(), events)

  @doc """
  Extends an existing `Ecto.Multi` with one `events` insert per event
  struct, in the order given.

  For each event the multi increments its stream's `version` by one
  (creating the stream row on first append) and the `"$all"` stream's
  `version` by one, then stores the event at that stream position.
  Each row's `event_type` is the struct's module name as a string and
  its `payload` is the struct encoded with `:erlang.term_to_binary/1`.
  `stream_id` `"$all"` is reserved and rejected.
  """
  def append(%Multi{} = multi, events) when is_list(events) do
    offset = length(Multi.to_list(multi))

    events
    |> Enum.with_index(offset)
    |> Enum.reduce(multi, fn {event, index}, multi ->
      Multi.run(multi, {:event, index}, fn repo, _changes ->
        insert_event(repo, event)
      end)
    end)
  end

  @doc """
  Returns stored events whose `event_type` is in `event_names` and whose
  `seq` is greater than `seq`, ordered by ascending `seq`. Each row's
  `payload` is decoded back into the original event struct.
  """
  def get_events(event_names, seq) do
    Repo.all(
      from e in Event,
        where: e.event_type in ^event_names and e.seq > ^seq,
        order_by: [asc: e.seq]
    )
    |> Enum.map(fn event -> %{event | payload: decode_payload(event.payload)} end)
  end

  @doc """
  Decodes a stored `payload` binary back into its event struct.
  """
  def decode_payload(payload), do: :erlang.binary_to_term(payload, [:safe])

  @doc """
  Resumes a `failed` listener by `name`.

  Clears the listener's `failed` status and `last_error`, then starts
  its runner under `ListenersSupervisor`. Delivery resumes from the
  persisted cursor, so the event that failed is retried first.

  Returns `:ok` on success, `{:error, :not_found}` when no listener row
  or configured listener module exists for `name`, and
  `{:error, :not_failed}` when the listener is not marked `failed`.
  """
  def resume_listener(name) do
    with %ListenerState{status: "failed"} = listener <-
           Repo.get_by(ListenerState, name: name),
         module when not is_nil(module) <- ListenersSupervisor.configured_listener(name),
         {:ok, _listener} <- mark_resumed(listener),
         {:ok, _pid} <-
           DynamicSupervisor.start_child(ListenersSupervisor, {ListenerRunner, module}) do
      :ok
    else
      nil -> {:error, :not_found}
      %ListenerState{} -> {:error, :not_failed}
      other -> other
    end
  end

  defp mark_resumed(listener) do
    listener
    |> ListenerState.changeset(%{status: "ok", last_error: nil})
    |> Repo.update()
  end

  defp insert_event(_repo, %{stream_id: stream_id} = event) when stream_id in [nil, ""] do
    {:error, insert_changeset(event, stream_id, nil)}
  end

  defp insert_event(repo, %{stream_id: stream_id} = event) do
    version = next_stream_version(repo, stream_id)
    _all_version = next_stream_version(repo, @all_stream)
    repo.insert(insert_changeset(event, stream_id, version))
  end

  defp next_stream_version(repo, stream_id) do
    {:ok, stream} =
      repo.insert(%Stream{stream_id: stream_id, version: 1},
        on_conflict: [inc: [version: 1]],
        conflict_target: :stream_id,
        returning: [:version]
      )

    stream.version
  end

  defp insert_changeset(event, stream_id, version) do
    %Event{}
    |> Changeset.change(
      stream_id: stream_id,
      version: version,
      event_type: inspect(event.__struct__),
      payload: :erlang.term_to_binary(event)
    )
    |> Changeset.validate_required([:stream_id])
    |> Changeset.validate_exclusion(:stream_id, [@all_stream], message: "is reserved")
    |> Changeset.unique_constraint(:version, name: :events_stream_id_version_index)
  end
end
