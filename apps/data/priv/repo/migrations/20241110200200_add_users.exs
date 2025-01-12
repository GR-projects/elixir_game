defmodule Data.Repo.Migrations.AddUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:name, :text)
      add(:email, :text)
      add(:password_hash, :text)
      add(:login, :text)

      # Adds inserted_at and updated_at fields
      timestamps()
    end
  end
end
