defmodule StreamServer.ConnectionHandlerErrorParser do
  def parse(error) do
    case error do
      "connection closed by peer: user_ended_call (code 0)" ->
        "user_ended_call"

      _ ->
        error
    end
  end
end
