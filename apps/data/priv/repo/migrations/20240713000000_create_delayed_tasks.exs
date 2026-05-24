defmodule Data.Repo.Migrations.CreateDelayedTasks do
  use Ecto.Migration

  def change do
    create table(:delayed_tasks, primary_key: false) do
      add :id, :string, primary_key: true
      add :type, :string, null: false
      add :state, :string, null: false, default: "scheduled"
      add :params, :map, null: false, default: %{}
      add :result, :map
      add :error, :text
      add :scheduled_at, :utc_datetime, null: false
      add :execute_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :attempts, :integer, null: false, default: 0
      add :max_attempts, :integer, null: false, default: 3
      add :priority, :integer, null: false, default: 0
      add :metadata, :map, null: false, default: %{}
      
      # Add any additional indexes as needed
      timestamps()
    end

    create index(:delayed_tasks, [:state, :execute_at])
    create index(:delayed_tasks, [:type, :state])
    
    # Add any additional indexes based on your query patterns
  end
end
