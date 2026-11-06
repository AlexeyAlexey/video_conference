defmodule VideoConference.StreamServerAdminPortal.EventStore do
  @moduledoc """
  Append-only event store for the stream server admin portal.

  Events are appended through `append/1` and `append/2`, which return an
  `Ecto.Multi` so an event and the change it describes commit (or roll
  back) in the same transaction. Each event carries a non-empty
  `stream_id` identifying the stream it belongs to; the store assigns
  it the next contiguous per-stream `version` inside the same
  transaction. `get_events/2` reads stored events back in `seq` order
  for future subscribers.
  """

  import Ecto.Query, warn: false

  alias Ecto.{Changeset, Multi}
  alias VideoConference.StreamServerAdminPortal.EventStore.Event
  alias VideoConference.StreamServerAdminPortal.Repo

  @doc """
  Returns an `Ecto.Multi` appending each event struct to its stream,
  suitable for `Ecto.Multi.merge/2`.
  """
  def append(events) when is_list(events), do: append(Multi.new(), events)

  @doc """
  Extends an existing `Ecto.Multi` with one `events` insert per event
  struct, in the order given.

  For each event the multi computes the next position on its stream —
  `MAX(version) + 1` over the event's `stream_id` — and stores the
  event at that position. Each row's `event_type` is the struct's
  module name as a string and its `payload` is the struct encoded with
  `:erlang.term_to_binary/1`.
  """
  def append(%Multi{} = multi, events) when is_list(events) do
    offset = length(Multi.to_list(multi))

    events
    |> Enum.with_index(offset)
    |> Enum.reduce(multi, fn {event, index}, multi ->
      Multi.run(multi, {:event, index}, fn repo, _changes ->
        version = next_stream_version(repo, event.stream_id)
        repo.insert(insert_changeset(event, event.stream_id, version))
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

  defp next_stream_version(repo, stream_id) do
    repo.one!(
      from(e in Event,
        where: e.stream_id == ^stream_id,
        select: coalesce(max(e.version), 0) + 1
      )
    )
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
    |> Changeset.unique_constraint(:version, name: :events_stream_id_version_index)
  end
end
