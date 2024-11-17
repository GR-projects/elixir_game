defmodule Data.User do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "users" do
    field(:name, :string)
    field(:email, :string)
    field(:password_hash, :string)
    field(:login, :string)

    # Automatically adds inserted_at and updated_at
    timestamps()
  end

  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(params), do: changeset(%__MODULE__{}, params)

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :password_hash, :login])
    |> validate_required([:name, :email, :password_hash, :login])
    # Example validation: login should be at least 3 characters long
    |> validate_length(:login, min: 3)
    # Ensure the email and name are unique
    |> unique_constraint(:email)
    |> unique_constraint(:name)
  end
end
