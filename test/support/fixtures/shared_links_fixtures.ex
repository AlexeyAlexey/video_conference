defmodule VideoConference.TelephoneSwitchboard.SharedLinksFixtures do
  # import Ecto.Query
  alias VideoConference.Repo

  alias VideoConference.TelephoneSwitchboard.SharedLinks.SharedLink

  def create_shared_link(attrs) when is_map(attrs) do
    opts = []

    opts =
      if attrs["password_required"] || attrs[:password_required] do
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

  def generate_shared_link_link_id, do: Ecto.UUID.generate()
  def generate_shared_link_id, do: System.unique_integer([:positive, :monotonic])
end
