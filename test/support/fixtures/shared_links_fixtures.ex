defmodule VideoConference.SharedLinksFixtures do
  # import Ecto.Query
  alias VideoConference.Repo

  alias VideoConference.SharedLinks.SharedLink

  def create_shared_link(attrs) when is_map(attrs) do
    opts = []

    opts =
      if attrs["password_required"] do
        Keyword.put(opts, :password_required, true)
      else
        opts
      end

    {:ok, shared_link} =
      %SharedLink{}
      |> SharedLink.changeset(attrs, opts)
      |> Repo.insert()

    shared_link
  end
end
