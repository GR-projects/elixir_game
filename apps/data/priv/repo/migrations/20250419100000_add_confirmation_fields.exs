defmodule Data.Repo.Migrations.AddConfirmationFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:confirmed_at, :utc_datetime, null: true)
    end
  end
end
