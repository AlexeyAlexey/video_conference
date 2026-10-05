defmodule VideoConference.TelephoneSwitchboard.PhoneCalls.PhoneCallParticipant do
  use Ecto.Schema
  import Ecto.Changeset

  alias VideoConference.TelephoneSwitchboard.PhoneCalls.PhoneCall

  schema "phone_call_participants" do
    field :phone_call_id, :integer
    field :phone_call_called_at, SqliteUnixMilliTimestampEctoType
    field :host_id, :integer
    field :phone, :integer
    field :direction, :string

    timestamps()
  end

  def call_changeset(participant, attrs, %PhoneCall{} = phone_call) do
    participant
    |> cast(attrs, [:host_id, :phone, :direction])
    |> put_change(:phone_call_id, phone_call.id)
    |> put_change(:phone_call_called_at, phone_call.called_at)
    |> validate_required([:phone_call_id, :phone_call_called_at, :phone, :direction])
    |> validate_inclusion(:direction, ["income", "outcome"])
  end

  def changeset(participant, attrs, _opts \\ []) do
    participant
    |> cast(attrs, [:phone_call_called_at, :host_id, :phone, :direction])
    |> validate_required([:phone_call_called_at, :phone, :direction])
    |> validate_inclusion(:direction, ["income", "outcome"])
  end
end
