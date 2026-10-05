defmodule VideoConference.TelephoneSwitchboard.PhoneCalls.PhoneCall do
  use Ecto.Schema
  import Ecto.Changeset

  schema "phone_calls" do
    field :called_at, SqliteUnixMilliTimestampEctoType
  end

  def changeset(call, attrs, _opts \\ []) do
    call
    |> cast(attrs, [:called_at])
    |> validate_required([:called_at])
  end
end
