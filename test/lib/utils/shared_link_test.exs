defmodule VideoConference.Utils.SharedLinkTest do
  use VideoConferenceWeb.ConnCase

  alias Utils.SharedLink

  setup do
    schema =
      Application.get_env(:video_conference, :frontend)
      |> Keyword.get(:schema)

    host =
      Application.get_env(:video_conference, :frontend)
      |> Keyword.get(:host)

    port =
      Application.get_env(:video_conference, :frontend)
      |> Keyword.get(:port)

    {:ok, schema: schema, host: host, port: port}
  end

  test "#url_for link_id", %{schema: schema, host: host, port: port} do
    link_id = "xxxxxxxxxxxxxxx"

    assert SharedLink.url_for(link_id: link_id) ==
             "#{schema}://#{host}:#{port}/conference/shared_link/#{link_id}"

    assert schema
    assert host
    assert port
  end
end
