defmodule VideoConference.TelephoneSwitchboard.HostPublicKey do
  @host_public_keys %{
    "local" => """
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkIezaXQicbiPMHv5oeA1
    Q2pwGP82pFGP7Kp/i4+f47IKHevHMSTm0jQhNTotAPZQH8iDJRBKSpXWXTGpAs56
    4e19oOHzwO0Kzc3f+3HRLAcjEmOH+h8eJg1rMk3ahkD+mXSdPoPwf3kXLSyJqp8v
    fA43XABDNAJM4Zq4lpM5+PFh47+Apfx+XK1Lob2HT9/s2TCeOlHNQp3wKLSmK1hj
    bjMBTiSIQcsWZE0aksW9rQxCXLrYw6g8MNwtm77OwTVH5Ahs0tzNhkKYWekob2/K
    zXfYLqFrCO2PyTLm3no2Q5Pnn01KU0S58mMgVLxCBYqoDi9CPKSnrGhA7t3nYHYP
    fwIDAQAB
    -----END PUBLIC KEY-----
    """
  }

  def fetch(host) when is_binary(host) do
    @host_public_keys[host]
    |> case do
      nil -> {:error, :not_found}
      key -> {:ok, key}
    end
  end
end
