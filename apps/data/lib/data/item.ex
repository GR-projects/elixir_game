defmodule Data.Item do
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "items" do
    field(:name, :string)
    field(:type, Ecto.Enum, values: [:sword, :bow, :staff])
    field(:position, Ecto.Enum, values: [:head, :left_hand, :right_hand, :two_hands, :legs])
    field(:sprite, :string)
    field(:equipped?, :boolean)
    has_one(:stats, Data.ItemStats)
    belongs_to(:character, Data.Character)

    # Automatically adds inserted_at and updated_at
    timestamps(type: :utc_datetime)
  end

  defimpl String.Chars, for: __MODULE__ do
    def to_string(item),
      do: "#{item.name} (#{item.type}): #{Data.Item.stats_to_string(item.stats)}"
  end

  defp stat_to_string(:health), do: "HEALTH"
  defp stat_to_string(:physical_att), do: "PHY ATT"
  defp stat_to_string(:magical_att), do: "MAG ATT"
  defp stat_to_string(_), do: nil

  def stats_to_string(stats) do
    fields = Map.keys(stats)

    Enum.map_join(fields, " ", &foo(&1, stats))
  end

  defp foo(field, stats) do
    case stat_to_string(field) do
      nil -> ""
      desc -> "+#{Map.get(stats, field)} #{desc}"
    end
  end
end
