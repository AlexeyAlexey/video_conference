defmodule SqliteUnixTimestampEctoType do
  use Ecto.Type

  def type, do: :integer

  # Cast from Elixir DateTime or integer to DB format
  def cast(%DateTime{} = datetime), do: {:ok, DateTime.to_unix(datetime)}
  def cast(integer) when is_integer(integer), do: {:ok, integer}
  def cast(_), do: :error

  # Convert raw DB integer to Elixir DateTime
  def load(integer) when is_integer(integer) do
    {:ok, DateTime.from_unix!(integer, :second)}
  end

  # Convert Elixir DateTime to raw DB integer
  def dump(%DateTime{} = datetime), do: {:ok, DateTime.to_unix(datetime)}
  def dump(integer) when is_integer(integer), do: {:ok, integer}
  def dump(_), do: :error
end
