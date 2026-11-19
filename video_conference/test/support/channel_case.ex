defmodule VideoConferenceWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import VideoConferenceWeb.ChannelCase

      # The default endpoint for testing
      @endpoint VideoConferenceWeb.Endpoint
    end
  end

  setup tags do
    VideoConference.DataCase.setup_sandbox(tags)
    :ok
  end
end
