defmodule VideoConferenceWeb.PhoneChannel do
  use Phoenix.Channel

  require Logger

  alias VideoConferenceWeb.PhoneChannelPresenter, as: Presenter
  alias VideoConference.TelephoneSwitchboard
  alias VideoConference.PhoneCalls

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
    if current_phone_number(socket) == to do
      {:reply, {:error, "You are trying to call yourself"}, socket}
    else
      PhoneCalls.call_to(%{
        from: current_phone_number(socket),
        to: to,
        called_at: DateTime.utc_now()
      })

      VideoConferenceWeb.Endpoint.broadcast!("phone:#{to}", "income_call", %{
        "from" => current_phone_number(socket)
      })

      params = %{
        "from" => "local@#{current_phone_number(socket)}",
        "to" => "local@#{to}",
        "direction" => "outcome",
        "host" => "local"
      }

      response =
        TelephoneSwitchboard.get_connection_options_for(
          "video",
          "phone_call",
          params
        )
        |> Map.merge(
          TelephoneSwitchboard.get_connection_options_for(
            "audio",
            "phone_call",
            params
          )
        )
        |> Map.merge(%{"to" => to})

      {:reply, {:ok, response}, socket}
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
    if socket.assigns.current_phone_number == from do
      {:noreply, socket}
    else
      params = %{
        "from" => "local@#{from}",
        "to" => "local@#{current_phone_number(socket)}",
        "direction" => "income",
        "host" => "local"
      }

      response =
        TelephoneSwitchboard.get_connection_options_for(
          "video",
          "phone_call",
          params
        )
        |> Map.merge(
          TelephoneSwitchboard.get_connection_options_for(
            "audio",
            "phone_call",
            params
          )
        )
        |> Map.merge(%{"from" => from})

      {:reply, {:ok, response}, socket}
    end
  end

  def handle_info("after_joined", socket) do
    res =
      PhoneCalls.get_current_income_calls(to: current_phone_number(socket))
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
