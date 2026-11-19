defmodule VideoConferenceWeb.LogController do
  use VideoConferenceWeb, :controller
  require Logger

  # I use this controller to debug remote mobile device

  def log(conn, %{"type" => "error"} = params) do
    Logger.error("js log: #{inspect(params)}")
    json(conn, %{})
  end

  def log(conn, %{"type" => "info"} = params) do
    Logger.info("js log: #{inspect(params)}")
    json(conn, %{})
  end

  def log(conn, %{"type" => "warning"} = params) do
    Logger.warning("js log: #{inspect(params)}")
    json(conn, %{})
  end
end
