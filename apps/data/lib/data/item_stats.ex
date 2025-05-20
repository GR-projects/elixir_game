defmodule Data.ItemStats do
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "item_stats" do
    field(:health, :integer)
    field(:physical_att, :integer)
    field(:magical_att, :integer)
    field(:physical_def, :integer)
    field(:magical_def, :integer)

    belongs_to(:item, Data.Item)

    # Automatically adds inserted_at and updated_at
    timestamps(type: :utc_datetime)
  end
end
