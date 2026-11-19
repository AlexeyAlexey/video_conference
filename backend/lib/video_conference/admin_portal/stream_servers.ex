defmodule VideoConference.AdminPortal.StreamServers do
  @moduledoc """
  The AdminPortal StreamServers context.

  Manages the directory of HTTP/3 stream servers — self-hosted and
  third-party — that can carry video, audio, and event streams.
  """

  import Ecto.Query, warn: false
  alias VideoConference.Repo

  alias VideoConference.AdminPortal.StreamServers.{
    KeyEncryption,
    PublicStreamServerKey,
    StreamServer
  }

  @doc """
  Returns all stream servers, ordered by name.
  """
  def list_stream_servers do
    Repo.all(from s in StreamServer, order_by: [asc: s.name])
  end

  @doc """
  Gets a single stream server.

  Raises `Ecto.NoResultsError` if the stream server does not exist.
  """
  def get_stream_server!(id), do: Repo.get!(StreamServer, id)

  @doc """
  Creates a stream server.
  """
  def create_stream_server(attrs \\ %{}) do
    %StreamServer{}
    |> StreamServer.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a stream server.
  """
  def update_stream_server(%StreamServer{} = stream_server, attrs) do
    stream_server
    |> StreamServer.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a stream server.
  """
  def delete_stream_server(%StreamServer{} = stream_server) do
    Repo.delete(stream_server)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stream server changes.
  """
  def change_stream_server(%StreamServer{} = stream_server, attrs \\ %{}) do
    StreamServer.changeset(stream_server, attrs)
  end

  @doc """
  Returns all stream servers ordered by name, each with its public stream
  server keys preloaded (ordered by name). Used by the grouped public keys
  admin page.
  """
  def list_stream_servers_with_public_keys do
    keys = from k in PublicStreamServerKey, order_by: [asc: k.name]

    Repo.all(
      from s in StreamServer,
        order_by: [asc: s.name],
        preload: [public_stream_server_keys: ^keys]
    )
  end

  @doc """
  Gets a single public stream server key.

  Raises `Ecto.NoResultsError` if the key does not exist.
  """
  def get_public_stream_server_key!(id), do: Repo.get!(PublicStreamServerKey, id)

  @doc """
  Creates a public stream server key. `private_key_pem` in `attrs` is
  encrypted before being stored as `private_key`.
  """
  def create_public_stream_server_key(attrs \\ %{}) do
    %PublicStreamServerKey{}
    |> PublicStreamServerKey.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Generates an RSA-2048 key pair and creates a public stream server key
  from `attrs` (`name`, `stream_server_id`, `description`) with no
  `public_key_id` — it can be filled in later once the stream server
  assigns it.
  """
  def generate_public_stream_server_key(attrs) do
    {public_key, private_key} = generate_key_pair()

    %PublicStreamServerKey{}
    |> PublicStreamServerKey.generate_changeset(attrs)
    |> Ecto.Changeset.put_change(:public_key, public_key)
    |> Ecto.Changeset.put_change(:private_key, KeyEncryption.encrypt(private_key))
    |> Repo.insert()
  end

  @doc """
  Generates an RSA-2048 key pair, returning `{public_key_pem,
  private_key_pem}`.
  """
  def generate_key_pair do
    jwk = JOSE.JWK.generate_key({:rsa, 2048})
    {_, private_key} = JOSE.JWK.to_pem(jwk)
    {_, public_key} = jwk |> JOSE.JWK.to_public() |> JOSE.JWK.to_pem()

    {public_key, private_key}
  end

  @doc """
  Updates a public stream server key. A blank `private_key_pem` in `attrs`
  keeps the stored private key.
  """
  def update_public_stream_server_key(%PublicStreamServerKey{} = key, attrs) do
    key
    |> PublicStreamServerKey.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a public stream server key.
  """
  def delete_public_stream_server_key(%PublicStreamServerKey{} = key) do
    Repo.delete(key)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking public stream server key
  changes.
  """
  def change_public_stream_server_key(%PublicStreamServerKey{} = key, attrs \\ %{}) do
    PublicStreamServerKey.changeset(key, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking the generate form fields.
  """
  def change_generate_public_stream_server_key(%PublicStreamServerKey{} = key, attrs \\ %{}) do
    PublicStreamServerKey.generate_changeset(key, attrs)
  end

  @doc """
  Decrypts the stored `private_key` of a public stream server key.
  """
  def decrypt_private_key(%PublicStreamServerKey{} = key) do
    KeyEncryption.decrypt(key.private_key)
  end
end
