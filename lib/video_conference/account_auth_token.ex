defmodule VideoConference.AccountAuthToken do
  use Joken.Config

  # 362 days
  def token_config, do: default_claims(default_exp: 60 * 60 * 24 * 362)
end
