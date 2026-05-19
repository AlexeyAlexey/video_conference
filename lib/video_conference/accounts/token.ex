defmodule VideoConference.Accounts.Token do
  use Ecto.Schema
  import Ecto.Query
  alias VideoConference.Accounts.Token
  alias VideoConference.Accounts.Phone

  @hash_algorithm :sha256
  @rand_size 32

  # It is very important to keep the magic link token expiry short,
  # since someone with access to the phone may take over the account.
  @session_validity_in_days 14

  schema "tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    field :authenticated_at, :naive_datetime
    belongs_to :phone, VideoConference.Accounts.Phone

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

  Therefore, storing them allows individual phone
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.
  """

  def build_session_token(%Phone{id: phone_id, authenticated_at: authenticated_at}) do
    token = :crypto.strong_rand_bytes(@rand_size)
    dt = authenticated_at || NaiveDateTime.utc_now(:second)

    {Base.url_encode64(token, padding: false),
     %Token{token: token, context: "session", phone_id: phone_id, authenticated_at: dt}}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the phone found by the token, if any, along with the token's creation time.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).
  """
  def verify_session_token_query(token) when is_binary(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: phone in assoc(token, :phone),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: {%{phone | authenticated_at: token.authenticated_at}, token.inserted_at}

    {:ok, query}
  end

  @doc """
  Builds a token and its hash to be delivered to the phone's phone.

  The non-hashed token is sent to the phone while the
  hashed part is stored in the database. The original token cannot be reconstructed,
  which means anyone with read-only access to the database cannot directly use
  the token in the application to gain access. Furthermore, if the phone changes
  their phone in the system, the tokens sent to the previous phone are no longer
  valid.

  Users can easily adapt the existing code to provide other types of delivery methods,
  for example, by phone numbers.
  """
  def build_phone_token(phone, context) do
    build_hashed_token(phone, context, phone.phone)
  end

  defp build_hashed_token(phone, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %Token{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       phone_id: phone.id
     }}
  end

  defp by_token_and_context_query(token, context) do
    from Token, where: [token: ^token, context: ^context]
  end
end
