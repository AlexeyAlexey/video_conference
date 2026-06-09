defmodule VideoConference.Accounts.PhoneCall do
  use Ecto.Schema
  import Ecto.Changeset

  schema "phone_calls" do
    field :from_host, :string
    field :from, :integer
    field :to_host, :string
    field :to, :integer
    field :called_at, :utc_datetime
    field :responded_at, :utc_datetime
    field :ended_at, :utc_datetime

    timestamps()
  end

  def call_changeset(call, attrs, _opts \\ []) do
    call
    |> cast(attrs, [:from, :to, :called_at])
  end

  def responded_changeset(call, attrs, _opts \\ []) do
    call
    |> cast(attrs, [:responded_at])
  end

  def ended_changeset(call, attrs, _opts \\ []) do
    call
    |> cast(attrs, [:ended_at])
  end
end
