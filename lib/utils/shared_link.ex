defmodule Utils.SharedLink do
  def url_for(link_id: link_id) do
    "#{schema()}://#{host()}:#{port()}/conference/shared_link/#{link_id}"
  end

  defp schema do
    Application.get_env(:video_conference, :frontend)
    |> Keyword.get(:schema)
  end

  defp host do
    Application.get_env(:video_conference, :frontend)
    |> Keyword.get(:host)
  end

  defp port do
    Application.get_env(:video_conference, :frontend)
    |> Keyword.get(:port)
  end
end
