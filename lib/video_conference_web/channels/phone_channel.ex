defmodule VideoConferenceWeb.PhoneChannel do
  use Phoenix.Channel

  require Logger

  alias VideoConference.Accounts
  alias VideoConference.TelephoneSwitchboard.OneToOneCallAuthToken
  alias VideoConferenceWeb.PhoneChannelPresenter, as: Presenter

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

  def handle_in("call", %{"to" => to}, socket) do
    if socket.assigns.current_phone_number == to do
      {:reply, {:error, "You are trying to call yourself"}, socket}
    else
      switchboard_auth_token =
        OneToOneCallAuthToken.generate(
          from: socket.assigns.current_phone_number,
          to: to,
          direction: "outcome"
        )

      VideoConferenceWeb.Endpoint.broadcast!("phone:#{to}", "income_call", %{
        "from" => socket.assigns.current_phone_number
      })

      {:reply, {:ok, %{"to" => to, "switchboard_auth_token" => switchboard_auth_token}}, socket}
    end
  end

  # TODO add calls table to track who to whom calls, to check if there ate a call
  def handle_in("income_call", %{"from" => from} = params, socket) do
    if socket.assigns.current_phone_number == from do
      {:noreply, socket}
    else
      switchboard_auth_token =
        OneToOneCallAuthToken.generate(
          from: from,
          to: socket.assigns.current_phone_number,
          direction: "income"
        )

      {:reply, {:ok, %{"from" => from, "switchboard_auth_token" => switchboard_auth_token}},
       socket}
    end
  end
end
