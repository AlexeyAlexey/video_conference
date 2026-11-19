defmodule VideoConference.StreamServerAdminPortal.EventStore.Stream do
  @moduledoc """
  An event stream in the stream server admin portal event store.

  `stream_id` is the opaque, unique identity of the stream (e.g. an
  aggregate's id — a UUID or any other non-empty string). `version` is
  a contiguous per-stream counter the store increments by one for each
  appended event; `created_at` records when the stream was created by
  its first append, and `deleted_at` is reserved for a future
  soft-delete of streams.

  The seeded `"$all"` stream counts every appended event — its
  `version` tracks the global event count (the same total order `seq`
  exposes on the `events` table).
  """
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}
  schema "streams" do
    field :stream_id, :string
    field :version, :integer, default: 0
    field :created_at, :utc_datetime_usec, autogenerate: {DateTime, :utc_now, []}
    field :deleted_at, :utc_datetime_usec
  end
end
