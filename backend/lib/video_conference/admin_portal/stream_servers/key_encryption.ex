defmodule VideoConference.AdminPortal.StreamServers.KeyEncryption do
  @moduledoc """
  Encrypts and decrypts `private_key` values stored on
  `PublicStreamServerKey` records.

  Uses `Plug.Crypto.MessageEncryptor` (AES-256-GCM). The encryption and
  signing keys are derived with SHA-256 from the
  `SECRET_KEY_TO_ENCRYPT_PRIVATE_KEY` environment secret so any
  arbitrary-length secret works.
  """

  @doc """
  Encrypts a plaintext private key, returning an opaque ciphertext binary.
  """
  def encrypt(plaintext) when is_binary(plaintext) do
    Plug.Crypto.MessageEncryptor.encrypt(plaintext, encryption_key(), signing_key())
  end

  @doc """
  Decrypts a stored ciphertext, returning `{:ok, plaintext}` or `:error`.
  """
  def decrypt(ciphertext) when is_binary(ciphertext) do
    Plug.Crypto.MessageEncryptor.decrypt(ciphertext, encryption_key(), signing_key())
  end

  defp encryption_key, do: derive("enc")
  defp signing_key, do: derive("sig")

  defp derive(purpose), do: :crypto.hash(:sha256, purpose <> ":" <> secret())

  defp secret do
    :video_conference
    |> Application.get_env(:stream_server_keys, [])
    |> Keyword.get(:encryption_secret)
    |> case do
      secret when is_binary(secret) and secret != "" ->
        secret

      _ ->
        raise "SECRET_KEY_TO_ENCRYPT_PRIVATE_KEY is not configured"
    end
  end
end
