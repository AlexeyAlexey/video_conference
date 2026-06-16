defmodule VideoConference.PhoneBooks.PhoneBook do
  use Ecto.Schema
  import Ecto.Changeset

  alias VideoConference.Accounts.Phone

  schema "phone_books" do
    field :host_id, :integer
    field :phone, :integer
    field :name, :string

    timestamps()

    belongs_to :account, Phone, foreign_key: :phone_id
  end

  def changeset(%__MODULE__{} = phone_book, attrs, _opts \\ []) do
    phone_book
    |> cast(attrs, [:phone_id, :host_id, :phone, :name])
    |> validate_required([:phone_id, :phone, :name])
  end
end
