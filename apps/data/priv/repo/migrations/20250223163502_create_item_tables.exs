defmodule Data.Repo.Migrations.CreateItemTables do
  use Ecto.Migration

  def change do
    create table(:characters) do
    end

    create table(:item_stats) do
      add(:health, :integer)
      add(:physical_att, :integer)
      add(:magical_att, :integer)
      add(:physical_def, :integer)
      add(:magical_def, :integer)
      add(:item_id, :integer, references: :items)

      timestamps(type: :utc_datetime)
    end

    create(index(:item_stats, [:item_id]))

    create table(:items) do
      add(:name, :string)
      add(:type, :string)
      add(:character_id, :integer, references: :characters)

      timestamps()
    end

    create(index(:items, [:character_id]))
  end
end
