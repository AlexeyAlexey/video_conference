defmodule VideoConferenceWeb.PageController do
  use VideoConferenceWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
