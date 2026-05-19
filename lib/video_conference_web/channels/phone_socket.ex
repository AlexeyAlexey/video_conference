defmodule VideoConferenceWeb.PhoneSocket do
  use Phoenix.Socket

  require Logger

  alias VideoConferenceWeb.AccountAuth
  alias VideoConference.Accounts.Scope

  # A Socket handler
  #
  # It's possible to control the websocket connection and
  # assign values that can be accessed by your channel topics.

  ## Channels
  # Uncomment the following line to define a "room:*" topic
  # pointing to the `VideoConferenceWeb.RoomChannel`:
  #
  channel "phone:*", VideoConferenceWeb.PhoneChannel
  #
  # To create a channel file, use the mix task:
  #
  #     mix phx.gen.channel Room
  #
  # See the [`Channels guide`](https://hexdocs.pm/phoenix/channels.html)
  # for further details.

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error` or `{:error, term}`. To control the
  # response the client receives in that case, [define an error handler in the
  # websocket
  # configuration](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#socket/3-websocket-configuration).
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(_params, socket, %{auth_token: auth_token}) when is_binary(auth_token) do
    case AccountAuth.fetch_current_scope_for_socket(auth_token) do
      {:ok, %Scope{phone: phone} = current_scope} ->
        socket =
          socket
          |> assign(:current_scope, current_scope)
          |> assign(:current_phone_number, phone.phone)

        {:ok, socket}

      {:error, :signature_error} ->
        :error

      {:error, error} ->
        Logger.error("Cannot be connected to a socket #{inspect(error)}")
        :error
    end
  end

  # def connect(_params, _socket, _connect_info), do: :error
  def connect(params, _socket, connect_info) do
    :error
  end

  # Socket IDs are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.VideoConferenceWeb.Endpoint.broadcast("phone_socket:#{current_phone_number}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  # def id(_socket), do: nil
  def id(socket), do: "phone_socket:#{socket.assigns.current_phone_number}"
end
