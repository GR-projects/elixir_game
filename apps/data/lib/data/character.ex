defmodule Data.Character do
  alias Data.User
  alias Data.Item
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @type t :: %__MODULE__{}

  schema "characters" do
    field(:name, :string)
    field(:type, :string)
    field(:level, :integer)
    field(:experience, :float)
    belongs_to(:user, User)
    has_many(:items, Item)

    # Automatically adds inserted_at and updated_at
    timestamps()
  end

  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(params), do: changeset(%__MODULE__{}, params)

  def changeset(character, attrs) do
    character
    |> cast(attrs, [:name, :type, :level, :experience, :user_id])
    |> validate_required([:name, :type, :level, :experience, :user_id])
  end

  def binding_name(), do: :character

  def base_query() do
    __MODULE__
    |> from(as: ^binding_name())
  end
end
