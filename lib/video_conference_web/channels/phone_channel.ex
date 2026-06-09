defmodule VideoConferenceWeb.PhoneChannel do
  use Phoenix.Channel

  require Logger

  alias VideoConference.Accounts
  alias VideoConferenceWeb.PhoneChannelPresenter, as: Presenter
  alias VideoConference.TelephoneSwitchboard

  # TODO add calls table to track calls (from, to, status (calling, rejected, not_picked_up, picked_up), initiated_at)

  def join(
        "phone:" <> phone_number,
        _params,
        socket
      ) do
    if String.to_integer(phone_number) == socket.assigns.current_phone_number do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_in("list_of_phones", _params, socket) do
    {:reply,
     {:ok,
      Accounts.all(except_phone_numbers: [socket.assigns.current_phone_number])
      |> Presenter.list_of_phones()}, socket}
  end

  def handle_in("call", %{"to_host" => "local" = to_host, "to" => to}, socket) do
    if current_phone_number(socket) == to do
      {:reply, {:error, "You are trying to call yourself"}, socket}
    else
      Accounts.call_to(%{
        from: current_phone_number(socket),
        to: to,
        called_at: DateTime.utc_now()
      })

      switchboard_audio_host = "local"
      switchboard_video_host = "local"
      from_host = "local"

      VideoConferenceWeb.Endpoint.broadcast!("phone:#{to}", "income_call", %{
        "from_host" => from_host,
        "from" => current_phone_number(socket)
      })

      params = %{
        "from" => "#{from_host}@#{current_phone_number(socket)}",
        "to" => "#{to_host}@#{to}",
        "direction" => "outcome",
        "host" => current_host()
      }

      response =
        TelephoneSwitchboard.get_connection_options_for(
          "video",
          switchboard_video_host,
          "phone_call",
          params
        )
        |> Map.merge(
          TelephoneSwitchboard.get_connection_options_for(
            "audio",
            switchboard_audio_host,
            "phone_call",
            params
          )
        )
        |> Map.merge(%{"to_host" => to_host, "to" => to})

      {:reply, {:ok, response}, socket}
    end
  end

  # TODO add calls table to track who to whom calls, to check if there ate a call
  def handle_in("income_call", %{"from_host" => "local", "from" => from} = _params, socket) do
    if socket.assigns.current_phone_number == from do
      {:noreply, socket}
    else
      switchboard_audio_host = "local"
      switchboard_video_host = "local"

      params = %{
        "from" => "local@#{from}",
        "to" => "local@#{current_phone_number(socket)}",
        "direction" => "income",
        "host" => current_host()
      }

      response =
        TelephoneSwitchboard.get_connection_options_for(
          "video",
          switchboard_video_host,
          "phone_call",
          params
        )
        |> Map.merge(
          TelephoneSwitchboard.get_connection_options_for(
            "audio",
            switchboard_audio_host,
            "phone_call",
            params
          )
        )
        |> Map.merge(%{"from_host" => "local", "from" => from})

      {:reply, {:ok, response}, socket}
    end
  end

  defp current_phone_number(socket), do: socket.assigns.current_phone_number

  defp current_host, do: "local"
end
