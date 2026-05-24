defmodule Data.User do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "users" do
    field(:name, :string)
    field(:email, :string)
    field(:password_hash, :string)
    field(:login, :string)
    field(:role, :string, default: "user")
    has_many(:characters, Data.Character)

    # Automatically adds inserted_at and updated_at
    timestamps()
  end

  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(params), do: changeset(%__MODULE__{}, params)

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :password_hash, :login, :role])
    |> validate_required([:name, :email, :password_hash, :login])
    |> validate_inclusion(:role, ["user", "admin"])
    |> validate_length(:login, min: 3)
    |> unique_constraint(:email)
    |> unique_constraint(:name)
  end
end
