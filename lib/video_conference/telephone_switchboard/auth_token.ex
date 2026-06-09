defmodule VideoConference.TelephoneSwitchboard.AuthToken do
  use Joken.Config

  # def token_config do
  #   default_claims()
  #   |> add_claim("from", nil, &(&1 != nil))
  # end

  def generate_token(params) do
    {:ok, claims} =
      generate_claims(params)

    encode_and_sign(claims, private_signer())
    |> case do
      {:ok, jwt, _claims} ->
        {:ok, jwt}

      error ->
        error
    end
  end

  def verify_token(jwt, public_key) do
    verify_and_validate(jwt, public_signer(public_key))
  end

  defp private_signer do
    Joken.Signer.create("RS256", %{
      "pem" => private_key()
    })
  end

  defp public_signer(public_key) when is_binary(public_key) do
    Joken.Signer.create("RS256", %{
      "pem" => public_key
    })
  end

  defp private_key do
    Application.get_env(:video_conference, :telephone_switchboard)
    |> Keyword.get(:private_key)
  end
end
