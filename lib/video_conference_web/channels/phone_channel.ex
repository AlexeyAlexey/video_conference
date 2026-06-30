defmodule VideoConferenceWeb.PhoneChannel do
  use Phoenix.Channel

  require Logger

  alias VideoConferenceWeb.PhoneChannelPresenter, as: Presenter
  alias VideoConference.TelephoneSwitchboard

  # TODO add calls table to track calls (from, to, status (calling, rejected, not_picked_up, picked_up), initiated_at)

  def join(
        "phone:" <> phone_number,
        _params,
        socket
      ) do
    if String.to_integer(phone_number) == socket.assigns.current_phone_number do
      send(self(), "after_joined")
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_in("call", %{"to_host_id" => _to_host_id, "to" => _to}, socket) do
    # TODO Implement
    {:reply, {:ok, %{}}, socket}
  end

  def handle_in("call", %{"to" => to}, socket) do
    TelephoneSwitchboard.connection_credentials(
      from_host_id: "local",
      from: current_phone_number(socket),
      to_host_id: "local",
      to: to,
      direction: "outcome",
      stream_type: ["audio", "video"]
    )
    |> case do
      {:ok, credentials} ->
        VideoConferenceWeb.Endpoint.broadcast!("phone:#{to}", "income_call", %{
          "from" => current_phone_number(socket)
        })

        {:reply, {:ok, credentials |> Map.merge(%{"to" => to})}, socket}

      {:error, "You are trying to call yourself" = error} ->
        {:reply, {:error, error}, socket}
    end
  end

  def handle_in(
        "income_call",
        %{"from_host_id" => _from_host_id, "from" => _from} = _params,
        socket
      ) do
    # TODO implement
    {:reply, {:ok, %{}}, socket}
  end

  def handle_in(
        "income_call",
        %{"from" => from},
        socket
      ) do
    TelephoneSwitchboard.connection_credentials(
      from_host_id: "local",
      from: from,
      to_host_id: "local",
      to: current_phone_number(socket),
      direction: "income",
      stream_type: ["audio", "video"]
    )
    |> case do
      {:ok, credentials} ->
        {:reply, {:ok, credentials |> Map.merge(%{"from" => from})}, socket}

      {:error, "You are trying to call yourself"} ->
        {:noreply, socket}
    end
  end

  def handle_info("after_joined", socket) do
    res =
      TelephoneSwitchboard.current_income_calls(to: current_phone_number(socket))
      |> Presenter.current_income_calls()

    VideoConferenceWeb.Endpoint.broadcast!(
      "phone:#{current_phone_number(socket)}",
      "current_income_calls",
      %{body: res}
    )

    {:noreply, socket}
  end

  defp current_phone_number(socket), do: socket.assigns.current_phone_number
end
