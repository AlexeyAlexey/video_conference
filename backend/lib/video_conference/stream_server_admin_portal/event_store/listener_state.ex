defmodule VideoConference.StreamServerAdminPortal.EventStore.ListenerState do
  @moduledoc """
  Durable state of a single event store listener.

  `name` is the listener's unique identity declared through
  `use EventStore.Listener` and `description` its human-readable
  purpose. `last_seen_seq` is the durable read cursor into the `events`
  table — it only advances after the listener's handler acknowledges an
  event. `status` is `"ok"` while the listener runs and `"failed"` once
  its retry budget is exhausted; `last_error` records the failure that
  halted it until `EventStore.resume_listener/1` clears it.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "event_listeners" do
    field :name, :string
    field :description, :string
    field :last_seen_seq, :integer, default: 0
    field :status, :string, default: "ok"
    field :last_error, :string
  end

  @doc """
  Validates listener state: `name` is required and unique, `status` is
  `"ok"` or `"failed"`, and `last_seen_seq` never goes negative.
  """
  def changeset(listener_state, attrs) do
    listener_state
    |> cast(attrs, [:name, :description, :last_seen_seq, :status, :last_error])
    |> validate_required([:name, :status])
    |> validate_length(:name, min: 1)
    |> validate_inclusion(:status, ["ok", "failed"])
    |> validate_number(:last_seen_seq, greater_than_or_equal_to: 0)
    |> unique_constraint(:name)
  end
end
