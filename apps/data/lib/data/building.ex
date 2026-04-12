defmodule Data.Building do
  @moduledoc """
  Schema for buildings.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "buildings" do
    field(:type, :string)
    field(:level, :integer, default: 1)
    belongs_to(:character, Data.Character)

    timestamps()
  end

  @type t :: %__MODULE__{}

  @spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(building, attrs) do
    building
    |> cast(attrs, [:type, :level, :character_id])
    |> validate_required([:type, :level, :character_id])
    |> validate_number(:level, greater_than_or_equal_to: 1)
    |> validate_inclusion(:type, ["house", "armory"])
    |> foreign_key_constraint(:character_id)
  end
end
