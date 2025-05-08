defmodule Data.Repo.Migrations.AddCharacterTable do
  use Ecto.Migration

  def up do
    create table(:characters) do
      add(:name, :text)
      add(:type, :string)
      add(:level, :integer)
      add(:experience, :float)
      add(:user_id, references(:users, on_delete: :delete_all)) # when user is deleted, their characters are also deleted.

      # Adds inserted_at and updated_at fields
      timestamps()
    end
  end

  def down do
    drop table(:characters)
  end
end
