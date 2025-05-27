defmodule Data.Repo.Migrations.AddCharacterTable do
  use Ecto.Migration

  def up do
    alter table(:characters) do
      add(:name, :text)
      add(:type, :string)
      add(:level, :integer)
      add(:experience, :float)
      # Adds inserted_at and updated_at fields
      timestamps()
    end
  end

  def down do
    drop table(:characters)
  end
end
