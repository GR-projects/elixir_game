defmodule Data.Repo.Migrations.CreateBuildings do
  use Ecto.Migration

  def change do
    create table(:buildings) do
      add(:type, :string, null: false)
      add(:level, :integer, null: false, default: 1)
      add(:character_id, references(:characters, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(index(:buildings, [:character_id]))
    create(index(:buildings, [:type]))
  end
end
