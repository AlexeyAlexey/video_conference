defmodule VideoConference.StreamServerAdminPortal.StreamServers.ApplicationStreamServer do
  @moduledoc """
  Join schema assigning a stream server to an application.

  Rows are deleted automatically when either side is removed
  (`on_delete: :delete_all` foreign keys), and the
  `(application_id, stream_server_id)` pair is unique.
  """
  use Ecto.Schema

  alias VideoConference.StreamServerAdminPortal.Applications.Application
  alias VideoConference.StreamServerAdminPortal.StreamServers.StreamServer

  @primary_key false
  @foreign_key_type :binary_id
  schema "application_stream_servers" do
    belongs_to :application, Application
    belongs_to :stream_server, StreamServer
  end
end
