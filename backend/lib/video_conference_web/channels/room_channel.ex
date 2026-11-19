defmodule VideoConferenceWeb.RoomChannel do
  use Phoenix.Channel

  require Logger

  def join(
        "room:" <> room_id,
        %{"participant_id" => participant_id, "auth_token" => auth_token},
        socket
      ) do
    VideoConference.Http3ServerToken.verify_and_validate(auth_token)
    |> case do
      {:ok, %{"room_id" => "params", "participant_id" => "params"}} ->
        socket =
          assign(socket, :current_participant_id, participant_id)
          |> assign(:room_id, room_id)

        send(self(), :after_join)
        {:ok, socket}

      _ ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def join("room:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_info(:after_join, socket) do
    broadcast!(socket, "participant_joined", %{
      participant_id: socket.assigns[:current_participant_id]
    })

    {:noreply, socket}
  end

  intercept ["participant_joined"]

  def handle_out("participant_joined", msg, socket) do
    if msg[:participant_id] == socket.assigns[:current_participant_id] do
      {:noreply, socket}
    else
      push(socket, "participant_joined", msg)
      {:noreply, socket}
    end
  end

  def terminate({:shutdown, :local_closed}, socket) do
    broadcast!(socket, "participant_left", %{
      participant_id: socket.assigns[:current_participant_id]
    })

    :ok
  end

  def terminate(reason, _socket) do
    Logger.info("terminated reason: #{inspect(reason)}")

    :ok
  end
end
