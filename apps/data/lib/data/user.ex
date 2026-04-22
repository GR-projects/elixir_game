defmodule Data.User do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "users" do
    field(:name, :string)
    field(:email, :string)
    field(:password_hash, :string)
    field(:login, :string)
    field(:confirmed_at, :utc_datetime)
    has_many(:characters, Data.Character)

    timestamps()
  end

  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(params), do: changeset(%__MODULE__{}, params)

  def changeset(user, attrs, opts \\ []) do
    required = Keyword.get(opts, :required, [:name, :email, :password_hash, :login])

    user
    |> cast(attrs, [:name, :email, :password_hash, :login, :confirmed_at])
    |> validate_required(required)
    |> validate_length(:login, min: 3)
    |> unique_constraint(:email)
    |> unique_constraint(:name)
  end
end
