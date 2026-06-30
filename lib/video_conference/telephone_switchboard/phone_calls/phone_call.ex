defmodule VideoConference.TelephoneSwitchboard.PhoneCalls.PhoneCall do
  use Ecto.Schema
  import Ecto.Changeset

  schema "phone_calls" do
    field :from_host_id, :integer
    field :from, :integer
    field :to_host_id, :integer
    field :to, :integer
    field :called_at, SqliteUnixTimestampEctoType
    field :responded_at, SqliteUnixTimestampEctoType
    field :ended_at, SqliteUnixTimestampEctoType

    timestamps()
  end

  def call_changeset(call, attrs, _opts \\ []) do
    call
    |> cast(attrs, [:from_host_id, :from, :to_host_id, :to, :called_at])
  end

  def responded_changeset(call, attrs, _opts \\ []) do
    call
    |> cast(attrs, [:responded_at])
  end

  def ended_changeset(call, attrs, _opts \\ []) do
    call
    |> cast(attrs, [:ended_at])
  end

  def changeset(call, attrs, _opts \\ []) do
    call
    |> cast(attrs, [:from_host_id, :from, :to_host_id, :to, :called_at, :responded_at, :ended_at])
  end
end
