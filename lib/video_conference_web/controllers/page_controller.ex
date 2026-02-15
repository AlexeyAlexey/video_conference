defmodule VideoConferenceWeb.PageController do
  use VideoConferenceWeb, :controller

  def home(conn, %{"room_id" => room_id} = _params) do
    participant_id = Enum.random(1..1_000)

    # {:ok, _claims} = VideoConference.Http3ServerToken.verify_and_validate(auth_token)

    http3_server_token =
      VideoConference.Http3ServerToken.generate_and_sign!(%{
        "room_id" => "params",
        "participant_id" => "params"
      })

    http3_host = System.get_env("HTTP3_SERVER_HOST")
    http3_port = System.get_env("HTTP3_SERVER_PORT")
    http3_server_cert_hash = System.get_env("HTTP3_SERVER_CERT_HASH")

    manager_protocol = if conn.scheme == :http, do: "ws", else: "wss"
    manager_host = System.get_env("PHX_HOST")
    manager_port = System.get_env("PORT")

    # room_link =
    #   url(
    #     ~p"/?#{%{"auth_token" => http3_server_token, "room_id" => room_id, "participant_id" => participant_id}}"
    #   )

    conn =
      assign(conn, :http3_server_token, http3_server_token)
      |> assign(room_id: room_id)
      |> assign(participant_id: participant_id)
      |> assign(http3_host: http3_host)
      |> assign(http3_port: http3_port)
      |> assign(http3_server_cert_hash: http3_server_cert_hash)
      |> assign(manager_protocol: manager_protocol)
      |> assign(manager_host: manager_host)
      |> assign(manager_port: manager_port)

    render(conn, :home)
  end

  def home(conn, _params) do
    participant_id = Enum.random(1..1_000)
    # Enum.random(1..1_000_000_000)
    room_id = Enum.random(1..1_000) |> Integer.to_string()

    http3_host = System.get_env("HTTP3_SERVER_HOST")
    http3_port = System.get_env("HTTP3_SERVER_PORT")
    http3_server_cert_hash = System.get_env("HTTP3_SERVER_CERT_HASH")

    manager_protocol = if conn.scheme == :http, do: "ws", else: "wss"
    manager_host = System.get_env("PHX_HOST")
    manager_port = System.get_env("PORT")

    http3_server_token =
      VideoConference.Http3ServerToken.generate_and_sign!(%{
        "room_id" => "params",
        "participant_id" => "params"
      })

    # room_link =
    #   url(
    #     ~p"/?#{%{"auth_token" => http3_server_token, "room_id" => room_id, "participant_id" => participant_id}}"
    #   )

    conn =
      assign(conn, :http3_server_token, http3_server_token)
      |> assign(room_id: room_id)
      |> assign(participant_id: participant_id)
      |> assign(http3_host: http3_host)
      |> assign(http3_port: http3_port)
      |> assign(http3_server_cert_hash: http3_server_cert_hash)
      |> assign(manager_protocol: manager_protocol)
      |> assign(manager_host: manager_host)
      |> assign(manager_port: manager_port)

    render(conn, :home)
  end
end
