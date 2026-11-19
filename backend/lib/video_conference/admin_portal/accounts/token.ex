defmodule VideoConference.AdminPortal.Accounts.Token do
  use Ecto.Schema
  import Ecto.Query
  alias VideoConference.AdminPortal.Accounts.{Admin, Token}

  @rand_size 32

  @session_validity_in_days 14

  schema "admin_tokens" do
    field :token, :binary
    field :context, :string
    field :authenticated_at, :utc_datetime
    belongs_to :admin, VideoConference.AdminPortal.Accounts.Admin

    timestamps(updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix's default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual admin
  sessions to be expired.
  """
  def build_session_token(%Admin{id: admin_id, authenticated_at: authenticated_at}) do
    token = :crypto.strong_rand_bytes(@rand_size)
    dt = authenticated_at || DateTime.utc_now(:second)

    {Base.url_encode64(token, padding: false),
     %Token{token: token, context: "session", admin_id: admin_id, authenticated_at: dt}}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the admin found by the token, if any, along with the token's creation time.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  def verify_session_token_query(token) when is_binary(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: admin in assoc(token, :admin),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: {%{admin | authenticated_at: token.authenticated_at}, token.inserted_at}

    {:ok, query}
  end

  defp by_token_and_context_query(token, context) do
    from Token, where: [token: ^token, context: ^context]
  end
end
