defmodule SqliteUnixMilliTimestampEctoType do
  use Ecto.Type

  def type, do: :integer

  # Cast from Elixir DateTime or integer to DB format (unix timestamp in milliseconds)
  def cast(%DateTime{} = datetime), do: {:ok, DateTime.to_unix(datetime, :millisecond)}
  def cast(integer) when is_integer(integer), do: {:ok, integer}
  def cast(_), do: :error

  # Convert raw DB integer (unix timestamp in milliseconds) to Elixir DateTime
  def load(integer) when is_integer(integer) do
    {:ok, DateTime.from_unix!(integer, :millisecond)}
  end

  # Convert Elixir DateTime to raw DB integer (unix timestamp in milliseconds)
  def dump(%DateTime{} = datetime), do: {:ok, DateTime.to_unix(datetime, :millisecond)}
  def dump(integer) when is_integer(integer), do: {:ok, integer}
  def dump(_), do: :error
end
