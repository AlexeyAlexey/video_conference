defmodule VideoConference.StreamServerAdminPortal.EventStore.Event do
  @moduledoc """
  A persisted domain event in the stream server admin portal event store.

  `seq` is a rowid-backed integer primary key giving a total insertion
  order and doubling as the read cursor. `stream_id` is an opaque string
  identifying the stream the event belongs to (e.g. an aggregate's id —
  a UUID or any other non-empty identity) and `version` is a contiguous
  per-stream position assigned by the store, unique with `stream_id`.
  `payload` holds the event struct encoded with
  `:erlang.term_to_binary/1`; `added_at` records when the event was
  stored.
  """
  use Ecto.Schema

  @primary_key {:seq, :id, autogenerate: true}
  schema "events" do
    field :stream_id, :string
    field :version, :integer
    field :event_type, :string
    field :payload, :binary
    field :added_at, :utc_datetime_usec, autogenerate: {DateTime, :utc_now, []}
  end
end
