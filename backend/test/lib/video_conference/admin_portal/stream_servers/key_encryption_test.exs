defmodule VideoConference.AdminPortal.StreamServers.KeyEncryptionTest do
  use VideoConference.DataCase, async: false

  alias VideoConference.AdminPortal.StreamServers.KeyEncryption

  defp with_secret(secret, fun) do
    old = Application.get_env(:video_conference, :stream_server_keys)
    Application.put_env(:video_conference, :stream_server_keys, encryption_secret: secret)
    on_exit(fn -> Application.put_env(:video_conference, :stream_server_keys, old) end)
    fun.()
  end

  test "encrypt/1 returns ciphertext that differs from the plaintext" do
    ciphertext = KeyEncryption.encrypt("secret-private-key")

    assert is_binary(ciphertext)
    refute ciphertext =~ "secret-private-key"
  end

  test "decrypt/1 round-trips the plaintext" do
    ciphertext = KeyEncryption.encrypt("secret-private-key")

    assert {:ok, "secret-private-key"} = KeyEncryption.decrypt(ciphertext)
  end

  test "decrypt/1 fails with a different secret" do
    ciphertext = KeyEncryption.encrypt("secret-private-key")

    with_secret("a-different-secret", fn ->
      assert :error = KeyEncryption.decrypt(ciphertext)
    end)
  end

  test "encrypt/1 raises when the secret is not configured" do
    with_secret(nil, fn ->
      assert_raise RuntimeError, "SECRET_KEY_TO_ENCRYPT_PRIVATE_KEY is not configured", fn ->
        KeyEncryption.encrypt("anything")
      end
    end)
  end
end
